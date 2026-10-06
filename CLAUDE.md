# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

RubyGopher is a job-search / interview-prep tool. A single Rails 8.1 backend serves two clients:

- **Admin panel** — server-rendered Slim views under `/admin` (Devise session auth), for editing the *default* content library.
- **User portal** — a standalone React SPA (`frontend/`) that talks to a JSON API (Devise JWT auth). Currently implements the "Interview Helper".

Backend is `backend/` (Rails 8.1, Ruby 4.0.7), frontend is `frontend/` (React 19 + Vite 8), and `services/` holds Go microservices (`sandboxd`, `fetcher`). They are separate apps deployed together via `docker-compose.yml`.

## Running the stack

Everything runs through Docker Compose (services: `web` Rails :3000, `jobs` Sidekiq, `karafka` Kafka consumers, `css` dartsass watch, `frontend` Vite :5173, `db` Postgres 18 :5432, `redis` Redis 8, `fetcher` Go job-board collector, `kafka` single-node KRaft (kafka:9092 inside, localhost:29092 from the host), and on an internal network `sandbox` Go sandboxd + `sandbox_db` throwaway Postgres + `sandbox_seed` one-shot that rebuilds it):

```bash
docker compose up            # boots the whole stack; gems/npm install on first run
```

Gems live in a named volume and only reinstall when the lockfile changes. Code is bind-mounted, so edits are live. The SPA points at `http://<host>:3000/api/v1` (see `frontend/src/config.js`); override with `VITE_API_BASE`.

## Backend commands (run inside the `web` container, or with a local Ruby 4.0 + Postgres 18)

```bash
bin/rails server                      # dev server
bundle exec rspec                     # full test suite
bundle exec rspec spec/models/user_spec.rb          # one file
bundle exec rspec spec/requests/api/v1/interview_questions_spec.rb:42   # one example by line
bin/rubocop                           # lint (rails-omakase style)
bin/ci                                # full CI: setup, rubocop, bundler-audit, importmap audit, brakeman
bin/rails db:prepare                  # create + load db/structure.sql
```

Note: the dev image installs `postgresql-client-18` from PGDG because `db/structure.sql` is written by `pg_dump`, which must match the Postgres 18 server. The `web` container sets `RAILS_ENV=development`. `spec/rails_helper.rb` **force-sets `RAILS_ENV=test`** so specs never hit the dev DB — keep that override if you touch the helper.

## Backend architecture

### Domain layout (`app/domains/`)
Business logic is organized by domain, not by Rails layer. Each domain (`identity/`, `interview/`, `playground/`, `tracker/`, `aggregator/`, `outbox/`) is a Ruby module namespace containing its own `api/`, `operations/`, and `contracts/` subdirs (plus `channels/`, `jobs/`, `api/entities/` where needed). These paths are autoloaded (`config.autoload_lib` + default app autoload). ActiveRecord models still live in the flat `app/models/`.

### API is Grape, not Rails controllers
The user-facing JSON API is built with **Grape**, mounted in `config/routes.rb` via `mount API => "/"`. Mount chain:

```
API (app/api/api.rb)
 └─ Identity::API::Base    → /api/v1  (Registrations, Sessions)
 └─ Interview::API::Base   → /api/v1  (Questions — interview_questions + interview_categories)
 └─ Playground::API::Base  → /api/v1  (Console — POST /console/eval; Sessions)
 └─ Tracker::API::Base     → /api/v1  (Applications — job applications + events; Outreaches — cold outreach + status history; Digest — follow-ups due + new vacancies)
```

Auth for the API is a hand-rolled JWT check: `Identity::Authenticate.call(token)` decodes the Warden JWT and honors Devise's JTIMatcher revocation; `Identity::API::AuthHelpers` (`current_user` / `authenticate!`) wraps it for Grape and `ApplicationCable::Connection` for WebSockets (JWT in the `token` query param). Reuse these in any new domain API or channel — do not add a second auth path.

### dry-rb operations
Multi-step business logic is a `Dry::Operation` subclass (`dry-operation`, the successor of the deprecated `dry-transaction`): `#call` lists the happy path, each `step` unwraps a `Success` or halts the flow on the first `Failure`, and the input is validated by a `dry-validation` contract. Canonical example: `Identity::Operations::SignUp` (validate → create_user → issue_token) with `Contracts::SignUpContract`. Steps are private methods returning `Success`/`Failure` from `dry-monads`; wrap multi-row writes in `transaction { }` via `Dry::Operation::Extensions::ActiveRecord`. Follow this pattern for new write operations rather than stuffing logic into the Grape endpoint.

### Tracker domain (job applications)
`Tracker::Operations::RecordApplication.new(hh:).call(user, input)` is the canonical multi-step operation: validate (`Contracts::RecordApplicationContract`: a `url`, or `company_name` + `vacancy_title`) → `resolve_posting`: `Aggregator::Sources.parse(url)` recognises hh.ru / career.habr.com / getmatch.ru links; a known `VacancyPosting` (source, external_id) is reused, an unknown hh.ru one is fetched live through `Aggregator::Clients::Hh` (public API, timeouts, `Error`/`NotFound`, injected for specs) and ingested with `IngestPosting`, an unknown habr/getmatch one needs company + title (`:invalid`), hh.ru downtime is `[:unavailable, msg]` → 503 → inside `transaction { }` the vacancy comes from the posting or from find-or-create `Company` (`Company.named`, case-insensitive) and `Vacancy` (`Vacancy.titled`) → `ensure_untracked` (one application per user+vacancy, `Failure([:duplicate, existing])` → 409) → create the `JobApplication` (`via_posting`, `apply_url`) with `last_activity_at = applied_at` → first `JobApplicationEvent` (`status_changed` → `applied`). `Operations::AddEvent.call(user, application_id, input)` appends an event and keeps the denormalised columns in step: `status` on `status_changed` (status required there), `last_activity_at` always, `next_follow_up_at` whenever the key is given (nil clears it). Cold outreach mirrors it: `Operations::RecordOutreach` (one per user+company, first event `no_response` at `sent_at`) and `Operations::ChangeOutreachStatus` (event + status; outreach events are status changes only). Failures are `[kind, payload]` tuples mapped by `fail!` in `Tracker::API::Helpers` (`:invalid` 422, `:duplicate` 409, `:not_found` 404); authorization is `current_user.job_applications` / `current_user.company_outreaches` everywhere. Responses use grape-entity (`Tracker::API::Entities::Application` / `Event`, `full: true` adds events). `Dry::Operation::Extensions::ActiveRecord` is not autoloaded by the gem (its loader ignores `extensions/*.rb`), so every operation that uses `transaction { }` starts with `require "dry/operation/extensions/active_record"`; a boot-time initializer was tried first and left the constant missing on the very first request after boot in development. Scopes: `JobApplication.active/archived/follow_up_due`.

Follow-up reminders are pull-based: `Tracker::Queries::Digest` (plain query object, not an operation: it writes nothing) gives `follow_ups_due` (active, `next_follow_up_at <= now`, oldest first), `follow_ups_upcoming` (next 7 days) and `new_vacancies_count` (vacancies created after `users.vacancies_seen_at`, or sign-up time, that have a non-manual posting — i.e. aggregator output; manual tracker vacancies never count). `GET /api/v1/digest` serves both; `POST /api/v1/digest/vacancies_seen` stamps the feed as seen. The SPA header shows `DigestBadge` (`src/hooks/useDigest.js` polls every minute and on tab focus); "Sent" posts a `follow_up_sent` event with `next_follow_up_at` a week ahead. Push reminders (Telegram) are planned through the Go notifier, not SMTP.

### Two auth realms (don't cross them)
- **Admin** — Devise `:database_authenticatable` session, `devise_for :admins` with full web routes. Controllers live under `AdminArea::` (module `admin_area`, URL still `/admin`). The `AdminArea` name deliberately avoids clashing with the `Admin` model.
- **User** — Devise `:jwt_authenticatable`, `devise_for :users, skip: :all` (no web routes — auth happens only through the Grape API). JTIMatcher revocation stores `jti` on `users`; logout rotates it, invalidating all issued tokens.

### Zeitwerk + Grape reload gotcha
`api` inflects to `API` (`config/initializers/zeitwerk.rb`). Grape classes are mounted by constant, and Rails unloads those constants on reload — leaving a stale mount that raises. `config/application.rb` installs a dev-only `FileUpdateChecker` that redraws routes whenever any `app/**/*.rb` changes. If you see stale-route errors in dev, this is why.

### Schema & data model
Schema is dumped as SQL — `db/structure.sql`, not `schema.rb` (`schema_format = :sql`) — to preserve Postgres-specific DDL. After migrations, review `structure.sql` in the diff.

Interview questions are the current core domain:
- `InterviewQuestion` with `user_id: nil` are **defaults** (edited via the admin panel); rows with a `user_id` are user-created.
- `visible_to(user)` = non-hidden defaults + the user's own. Users "delete" a default by creating a `HiddenInterviewQuestion` (soft hide) rather than destroying the shared row.
- Per-user ordering is stored separately in `user_question_orders` / `user_category_orders` (`reorder_questions!` / `reorder_categories!` on `User`) so each user reorders shared content independently.
- Answer content is a **TipTap document stored as JSON** in `interview_questions.body`. The API parses/serializes it; `InterviewQuestion.legacy_to_body` converts old answer/code/language columns into TipTap JSON.

### Playground (live-coding console)
`POST /api/v1/console/eval` runs a user-supplied snippet (`context`: `rails`, `ruby` or `go`) and returns `{output, error, context, duration_ms}` — this is what the SPA's "Live console" tab talks to. Only captured stdout/stderr comes back: the value of the last expression is deliberately not echoed, so print with `p`/`pp`/`puts`. The endpoint requires auth, caps the snippet at 64 KiB (`Playground::Runner::MAX_CODE_LENGTH`) and rate-limits per user (`Playground::RateLimit`: token bucket in Redis, refilled and spent atomically by a Lua script; 429 with `Retry-After`).

With `SANDBOX_URL` set (the compose default) **all contexts** go through `Playground::Runners::Sandbox` to **sandboxd** (`services/sandboxd`, Go), authenticated with the shared `SANDBOX_TOKEN`:

- `ruby` — bare `ruby -r evaluator.rb` inside the sandbox container.
- `rails` — `bin/rails runner` inside the sandbox container. The app is bind-mounted read-only with `/dev/null` over `config/master.key` and `RAILS_MASTER_KEY_PATH=/nonexistent` (see `config/application.rb`), so it boots with empty credentials; `SECRET_KEY_BASE` and `DEVISE_JWT_SECRET_KEY` are dummy env values. It connects to `sandbox_db`, a separate Postgres on tmpfs that `sandbox_seed` rebuilds on every stack start: `backend/bin/sandbox-db-reset` drops/creates the database, loads `db/structure.sql` and runs `db/sandbox_seed.rb` (FactoryBot-generated companies, vacancies, applications, demo user `demo@sandbox.local`, a few questions) and (re)creates the `console` role: `default_transaction_read_only`, `statement_timeout = 5s`, SELECT-only. **Never copy real data into it.** `bin/sandbox-db-reset` on the host reruns the seed. Boot is ~0.5s with a warm bootsnap cache in tmpfs.
- `go` — the snippet is a full `package main` program: `go build` (30s allowance, `BuildError` on failure) then the binary under the user's timeout (`ExitError` with the exit status on a crash; output printed before a timeout is kept). The Go toolchain is copied from the build stage into the image; `GOCACHE` lives in tmpfs and sandboxd warms it with a hello world at start-up. Offline and `CGO_ENABLED=0`, so stdlib only.

Without `SANDBOX_URL` (tests, bare local dev) the local runners are used: `Runners::RailsProcess` forks the Puma worker (re-establishing its own DB pool, `exit!` to skip at_exit hooks) and `Runners::RubyProcess` spawns `ruby` via `Bundler.with_unbundled_env`; `go` has no local runner (`Runners::SandboxOnly` answers with a ConsoleError). Request specs stub `Sandbox.url` to nil to force this path.

All runners share `Playground::Evaluator`, which must stay **free of Rails APIs** (the plain-Ruby runner loads it with `ruby -r`). It enforces the snippet timeout from inside the process (so output printed before the cut-off survives) and caps captured output at write time; the supervisor's hard kill is the backstop.

sandboxd: `main.go` wires the HTTP server, graceful shutdown and the `-check` healthcheck flag; `internal/api` validates `POST /eval` (`{code, context: ruby|rails|go, timeout}`), checks the bearer token and caps concurrency with a semaphore (503 when full); `internal/sandbox` writes the snippet to a temp file, builds the per-context command (rails gets only an allow-listed env; go is a build step plus a run step), runs it in its own process group with a boot allowance on top of the timeout, kills the whole group, caps output and distinguishes OOM kills. `go test ./...` runs on the host (Go 1.27) and again inside the Docker build. The sandbox container hardening lives in `docker-compose.yml`.

Arbitrary code execution is gated: `Playground::Runner.enabled?` is true only in `Rails.env.local?` (dev/test) or with `PLAYGROUND_CONSOLE=true`. Never expose the endpoint without the sandbox.

### Shared console sessions (ActionCable)
`ConsoleSession` (`console_sessions`: `token`, `code`, `context`, `result` jsonb) is a shared snippet anyone with the token can join; the SPA puts it in the URL as `?session=<token>`. `Playground::API::Sessions` creates/fetches one (`POST/GET /api/v1/console/sessions[/:token]`); `POST /console/eval` with `session` stores the result on it (`record_run!`, with `by: user_id`) and broadcasts. `Playground::Channels::ConsoleSessionChannel` (`stream_for session`) transmits the state (plus `participants`) on subscribe and handles `update` (last write wins: `apply!` persists and broadcasts `{type: "state", code, context, by}`), `running` and `cursor` (relayed as `{type: "cursor", by, name, pos}`). Presence is a Redis set per session (`Playground::Presence`, one uuid per subscription, broadcast as `{type: "presence", participants, left?}`). Sessions expire `ConsoleSession::TTL` (7 days) after the last update: the `active`/`stale` scopes gate every lookup, and `POST /console/sessions` enqueues `Playground::Jobs::PurgeConsoleSessionsJob` (queue `low`, calls `Operations::PurgeStaleSessions`) so the table trims itself without a scheduler. Test env uses the ActiveJob `:test` adapter (`have_been_enqueued`). Dev cable adapter is Redis (`config/cable.yml`) so any process can broadcast; `allowed_request_origins` mirrors the CORS rule. Frontend: `src/api/cable.js` (one consumer, token in the WS URL), `src/hooks/useConsoleSession.js` (subscribe, debounced `update`, throttled `cursor`, presence and cursors state, ignores echoes by comparing `by` with the JWT `sub`), `src/lib/remoteCursors.js` (CodeMirror StateField + widget decorations for other participants' carets, fed through `CodeEditor`'s `cursors`/`onCursor` props), Share / Copy link / Leave and the `live · N` indicator in `Console.jsx`. Specs: `spec/channels`, `spec/domains/playground/channels`, `spec/requests/api/v1/console_sessions_spec.rb` (`have_broadcasted_to`, cable test adapter).

### Sandbox service commands
```bash
cd services/sandboxd && go test ./... && go vet ./...   # unit tests on the host
docker compose build sandbox                            # image build also runs the Go tests
docker compose up -d sandbox                            # starts sandbox_db + sandbox_seed first; web talks to http://sandbox:8080
bin/sandbox-db-reset                                    # rebuild sandbox_db with synthetic data (host side)
```

### Background jobs
Sidekiq (`config.active_job.queue_adapter = :sidekiq`), Redis via `REDIS_URL`. Runs as the `jobs` compose service. Jobs hold no logic: they call an operation (`Playground::Jobs::PurgeConsoleSessionsJob`, `Outbox::Jobs::PublishJob`).

### Kafka (Karafka)
`backend/karafka.rb` boots Rails and declares the topics; the `karafka` service runs `karafka topics migrate && karafka server`, so topics come from code, never auto-created (`KAFKA_AUTO_CREATE_TOPICS_ENABLE=false`). Bootstrap servers from `KAFKA_BOOTSTRAP_SERVERS`.

- **Outbox (producer side).** `Outbox::Event` (`outbox_events`: topic, key, event_type, payload, published_at) is written inside the operation's transaction via `Tracker::Events` (`application.recorded`, `application.event_added`, `outreach.recorded`, `outreach.status_changed`; key `user:<id>` for per-user ordering). `after_commit` enqueues `Outbox::Jobs::PublishJob` (queue `critical`), which drains `unpublished` rows in id order under `FOR UPDATE SKIP LOCKED`, `produce_many_sync` to `tracker.events`, then stamps `published_at`. At-least-once: the message envelope carries `event_id`, `type`, `recorded_at` for consumer dedupe. Specs stub `Karafka.producer` with an `instance_double(WaterDrop::Producer)`.
- **Consumer side.** `Aggregator::Consumers::RawPostingsConsumer` (`vacancies.raw`, DLQ `vacancies.raw.dlq` after 3 retries) calls `Aggregator::Operations::IngestPosting` per message: validate (`IngestPostingContract`, source must not be `manual`) → if the posting (`source`, `external_id`) exists, refresh `last_seen_at`/`active`/`url`/`raw` → else company by (`source`, `external_id`), then by name, else create; vacancy by company + `titled`, else create; create the posting. Invalid payloads are logged and skipped (no retry), everything else raises into Karafka's retry/DLQ. `ApplicationConsumer` lives in `app/consumers`. Consumer specs use `karafka-testing` (`karafka.consumer_for`, `karafka.produce`).
- **Fetcher (`services/fetcher`, Go).** `internal/source.Source` is the adapter interface (`Name()`, `Fetch(ctx, query)`); adapters: `source/hh` (public API, `HH_TOKEN` optional bearer, written against the documented shape because hh.ru is geo-blocked outside Russia: 451/403), `source/habr` (goquery over the exact skill listings `career.habr.com/vacancies/skills/ruby|golang?sort=date&type=all`, free-text `?q=` only for unknown queries; skips branded `vacancy-card--bp` cards, parses salary text and chips), `source/hirify` (`api.hirify.me/api/vacancies?search=&remote_type[]=`, `HIRIFY_REMOTE_TYPES` default `russia` because most listings are foreign remote jobs and other filters sit behind hirify premium; page URL `hirify.me/jobs/<slug>`, placeholder employers fall back to the LinkedIn slug, yearly salaries divided by 12). Board search is fuzzy, so `source.Relevant(query, title, stack...)` keeps only postings naming the language (`ruby|rails|ror`, `go|golang` as whole words) in the title or skills/stack; `Language` is set from the query. `internal/fetcher` runs every source × query in goroutines, publishes per result, logs failures per source and keeps partial results; no dedupe cache on purpose (the consumer is idempotent, republishing refreshes `last_seen_at`). `internal/producer` wraps franz-go (`ProduceSync`, key `source:external_id`). Config: `KAFKA_BROKERS`, `FETCH_INTERVAL` (15m), `FETCH_SOURCES`, `FETCH_QUERIES` (ruby,go), `-once` for a single run. Tests use httptest servers and HTML/JSON fixtures in `testdata/`; `go test ./...` runs on the host and in the image build. `source/getmatch` reads getmatch.ru's JSON list (`offers`, `meta.total/offset/limit`, specialization filter `sp=ruby|golang`, inactive and non-vacancy offers skipped, `published_at` has no zone and is read as Moscow time); endpoint `getmatch.ru/api/offers?sp=&offset=&limit=` (inferred from a captured response, confirmed by a live run). getmatch.ru intermittently refuses TLS from non-Russian addresses.
- Message shape for `vacancies.raw` (what the Go fetchers must produce): `{source, external_id, url, title, company: {name, external_id?, website?}, language?, location?, work_mode?, salary_min?, salary_max?, currency?, description?, published_at?, raw?}`.

## Frontend architecture (`frontend/`)

Plain Vite 8 + React 19 (no router, no state library). `App.jsx` switches between `Login` and the authed shell based on `useAuth().authed`; the shell is a header with tabs (`TABS` in `App.jsx`) over three pages — `Tracker` (applications + cold outreach: `src/pages/Tracker.jsx` with `components/tracker/*`, data via `hooks/useTracker.js` and `api/tracker.js`, helpers in `lib/tracker.js`; the new-application form takes a vacancy link and reveals company/title fields on a 422), `Helper` (Interview Helper) and `Console` (Live console). The active tab is remembered in `localStorage` (`tab`), as are the console's context and one draft per context (`console:code:<context>`), each seeded with its own sample. The console is a resizable split: CodeMirror 6 with the Ruby or Go legacy mode + darcula theme (`src/components/CodeEditor.jsx`, `language` prop) on the left, evaluation result on the right; Ctrl/Cmd+Enter runs. Auth token is kept in `localStorage` (`src/api/client.js`); `request()` attaches `Authorization: Bearer` and centralizes error handling (throws `{status, data}`). API wrappers live in `src/api/`. Rich answer editing uses **TipTap 3** (`@tiptap/react`; toolbar state comes from `useEditorState`, since v3 `useEditor` no longer re-renders on every transaction, `src/lib/editor.js`, `src/components/RichEditor.jsx` / `RichContent.jsx`) — the document shape must stay compatible with the backend `body` JSON.

## Testing

RSpec + FactoryBot + shoulda-matchers + rspec-sidekiq. Generators are configured for RSpec/FactoryBot only (no view/helper/routing specs). Specs are split into `spec/models/`, `spec/domains/<domain>/` (operations, channels, jobs) and `spec/requests/api/v1/` (full Grape API request specs); `infer_spec_type_from_file_location!` is on, so shoulda-matchers work in `spec/models`. Factories in `spec/factories/`.
