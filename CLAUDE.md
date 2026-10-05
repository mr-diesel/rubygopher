# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

RubyGopher is a job-search / interview-prep tool. A single Rails 8.1 backend serves two clients:

- **Admin panel** — server-rendered Slim views under `/admin` (Devise session auth), for editing the *default* content library.
- **User portal** — a standalone React SPA (`frontend/`) that talks to a JSON API (Devise JWT auth). Currently implements the "Interview Helper".

Backend is `backend/` (Rails 8.1, Ruby 4.0.7), frontend is `frontend/` (React 19 + Vite 8), and `services/` holds Go microservices (currently `sandboxd`). They are separate apps deployed together via `docker-compose.yml`.

## Running the stack

Everything runs through Docker Compose (services: `web` Rails :3000, `jobs` Sidekiq, `css` dartsass watch, `frontend` Vite :5173, `db` Postgres 18 :5432, `redis` Redis 8, and on an internal network `sandbox` Go sandboxd + `sandbox_db` read-only Postgres copy):

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

Note: the `web` container sets `RAILS_ENV=development`. `spec/rails_helper.rb` **force-sets `RAILS_ENV=test`** so specs never hit the dev DB — keep that override if you touch the helper.

## Backend architecture

### Domain layout (`app/domains/`)
Business logic is organized by domain, not by Rails layer. Each domain (`identity/`, `interview/`) is a Ruby module namespace containing its own `api/`, `operations/`, and `contracts/` subdirs. These paths are autoloaded (`config.autoload_lib` + default app autoload). ActiveRecord models still live in the flat `app/models/`.

### API is Grape, not Rails controllers
The user-facing JSON API is built with **Grape**, mounted in `config/routes.rb` via `mount API => "/"`. Mount chain:

```
API (app/api/api.rb)
 └─ Identity::API::Base    → /api/v1  (Registrations, Sessions)
 └─ Interview::API::Base   → /api/v1  (Questions — interview_questions + interview_categories)
 └─ Playground::API::Base  → /api/v1  (Console — POST /console/eval)
```

Auth for the API is a hand-rolled JWT check in `Identity::API::AuthHelpers` (`current_user` / `authenticate!`), decoding the Warden JWT and honoring Devise's JTIMatcher revocation. Reuse this helper (`helpers Identity::API::AuthHelpers`) in any new domain API — do not add a second auth path.

### dry-rb operations
Multi-step business logic is a `Dry::Operation` subclass (`dry-operation`, the successor of the deprecated `dry-transaction`): `#call` lists the happy path, each `step` unwraps a `Success` or halts the flow on the first `Failure`, and the input is validated by a `dry-validation` contract. Canonical example: `Identity::Operations::SignUp` (validate → create_user → issue_token) with `Contracts::SignUpContract`. Steps are private methods returning `Success`/`Failure` from `dry-monads`; wrap multi-row writes in `transaction { }` via `Dry::Operation::Extensions::ActiveRecord`. Follow this pattern for new write operations rather than stuffing logic into the Grape endpoint.

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
`POST /api/v1/console/eval` runs a user-supplied Ruby snippet and returns `{output, error, context, duration_ms}` — this is what the SPA's "Rails console" tab talks to. Only captured stdout/stderr comes back: the value of the last expression is deliberately not echoed, so print with `p`/`pp`/`puts`. The endpoint requires auth, caps the snippet at 64 KiB (`Playground::Runner::MAX_CODE_LENGTH`) and rate-limits per user (`Playground::RateLimit`: token bucket in Redis, refilled and spent atomically by a Lua script; 429 with `Retry-After`).

With `SANDBOX_URL` set (the compose default) **both contexts** go through `Playground::Runners::Sandbox` to **sandboxd** (`services/sandboxd`, Go), authenticated with the shared `SANDBOX_TOKEN`:

- `ruby` — bare `ruby -r evaluator.rb` inside the sandbox container.
- `rails` — `bin/rails runner` inside the sandbox container. The app is bind-mounted read-only with `/dev/null` over `config/master.key` and `RAILS_MASTER_KEY_PATH=/nonexistent` (see `config/application.rb`), so it boots with empty credentials; `SECRET_KEY_BASE` and `DEVISE_JWT_SECRET_KEY` are dummy env values. It connects to `sandbox_db`, a separate Postgres with a copy of the dev database (`bin/sandbox-db-sync` from the host) through the `console` role: `default_transaction_read_only`, `statement_timeout = 5s`, SELECT-only (`services/sandboxd/db-init`). Boot is ~0.5s with a warm bootsnap cache in tmpfs.

Without `SANDBOX_URL` (tests, bare local dev) the local runners are used: `Runners::RailsProcess` forks the Puma worker (re-establishing its own DB pool, `exit!` to skip at_exit hooks) and `Runners::RubyProcess` spawns `ruby` via `Bundler.with_unbundled_env`. Request specs stub `Sandbox.url` to nil to force this path.

All runners share `Playground::Evaluator`, which must stay **free of Rails APIs** (the plain-Ruby runner loads it with `ruby -r`). It enforces the snippet timeout from inside the process (so output printed before the cut-off survives) and caps captured output at write time; the supervisor's hard kill is the backstop.

sandboxd: `main.go` wires the HTTP server, graceful shutdown and the `-check` healthcheck flag; `internal/api` validates `POST /eval` (`{code, context: ruby|rails, timeout}`), checks the bearer token and caps concurrency with a semaphore (503 when full); `internal/sandbox` writes the snippet to a temp file, builds the per-context command (rails gets only an allow-listed env), runs it in its own process group with a boot allowance on top of the timeout, kills the whole group, caps output and distinguishes OOM kills. `go test ./...` runs on the host (Go 1.27) and again inside the Docker build. The sandbox container hardening lives in `docker-compose.yml`.

Arbitrary code execution is gated: `Playground::Runner.enabled?` is true only in `Rails.env.local?` (dev/test) or with `PLAYGROUND_CONSOLE=true`. Never expose the endpoint without the sandbox.

### Sandbox service commands
```bash
cd services/sandboxd && go test ./... && go vet ./...   # unit tests on the host
docker compose build sandbox                            # image build also runs the Go tests
docker compose up -d sandbox                            # starts sandbox_db too; web talks to http://sandbox:8080
bin/sandbox-db-sync                                     # copy the dev database into sandbox_db (host side)
```

### Background jobs
Sidekiq (`config.active_job.queue_adapter = :sidekiq`), Redis via `REDIS_URL`. Runs as the `jobs` compose service.

## Frontend architecture (`frontend/`)

Plain Vite 8 + React 19 (no router, no state library). `App.jsx` switches between `Login` and the authed shell based on `useAuth().authed`; the shell is a header with tabs (`TABS` in `App.jsx`) over two pages — `Helper` (Interview Helper) and `Console` (Rails console). The active tab is remembered in `localStorage` (`tab`), as is the console's draft code and context. The console is a resizable split: CodeMirror 6 with the Ruby legacy mode + darcula theme (`src/components/CodeEditor.jsx`) on the left, evaluation result on the right; Ctrl/Cmd+Enter runs. Auth token is kept in `localStorage` (`src/api/client.js`); `request()` attaches `Authorization: Bearer` and centralizes error handling (throws `{status, data}`). API wrappers live in `src/api/`. Rich answer editing uses **TipTap 3** (`@tiptap/react`; toolbar state comes from `useEditorState`, since v3 `useEditor` no longer re-renders on every transaction, `src/lib/editor.js`, `src/components/RichEditor.jsx` / `RichContent.jsx`) — the document shape must stay compatible with the backend `body` JSON.

## Testing

RSpec + FactoryBot + shoulda-matchers + rspec-sidekiq. Generators are configured for RSpec/FactoryBot only (no view/helper/routing specs). Specs are split into `spec/models/` and `spec/requests/api/v1/` (full Grape API request specs). Factories in `spec/factories/`.
