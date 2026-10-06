# RubyGopher

A job-search workbench for Ruby and Go developers, built as a public portfolio project.
Rails backend, React portal, Go microservices, everything in Docker.

The point of the repository is to show production-grade engineering on a small codebase:
domain-driven Rails with dry-rb, a Grape API with two authentication realms, an isolated
code sandbox written in Go, SQL-first schema management, and a real test suite.

## What it does

| Part | Status | Summary |
|---|---|---|
| Interview Helper | done | Personal cheat-sheet library: questions grouped by category, rich answers (TipTap documents with syntax-highlighted code blocks), per-user ordering and hiding of shared defaults, admin panel for the default library |
| Live console | done | Run snippets from the browser: plain Ruby, Ruby with the Rails app and models loaded, or a Go program (compiled and run, stdlib only). Everything executes in **sandboxd**, a Go service inside a locked-down container, against a throwaway database with synthetic data. **Share** turns the editor into a live session: anyone with the link edits and runs the same snippet over ActionCable (last write wins), with a participant count and everyone's carets; sessions expire a week after the last edit |
| Application tracker | in progress | Companies, vacancies, applications and their event history. API: record an application from a job-board link alone (hh.ru vacancies are fetched from the public API on the spot) or from company + title, one application per vacancy, append status changes / notes / follow-ups, list and filter; record cold outreach to a company and track its status history; a digest of due follow-ups and new vacancies in the portal header (new vacancies light up once the aggregator feeds the database). Next: funnel analytics, the portal tab, and an API for an external AI assistant (ChatGPT, Claude) to keep the journal via a personal token |
| Vacancy aggregator | in progress | Ruby/Go postings from hh.ru, getmatch and Habr Career, deduplicated into canonical vacancies. A Go **fetcher** polls hh.ru, Habr Career, getmatch.ru and hirify.me (adapters behind one `Source` interface, run concurrently) and publishes `vacancies.raw`; a Karafka consumer turns each message into company + vacancy + posting, idempotently |
| AI interview trainer | planned | Question generation and answer review through an OpenAI-compatible LLM API |

## Architecture

```
frontend/   React 19 + Vite SPA, JWT auth, talks to /api/v1
backend/    Rails 8.1 (Ruby 4.0)
  app/domains/<name>/      business logic by domain: api/ (Grape), operations/ (Dry::Operation), contracts/ (dry-validation)
  app/controllers/admin_area/   server-rendered admin panel (Devise session)
  app/models/              ActiveRecord models, shared by all domains
  db/structure.sql         schema source of truth (Postgres-specific DDL preserved)
services/
  sandboxd/   Go: supervises untrusted Ruby snippets (timeout, process-group kill, output cap, concurrency limit)
  fetcher/    Go: job-board adapters (hh.ru API, Habr Career HTML, getmatch.ru API, hirify.me API) → Kafka producer
```

Messaging: Kafka (single-node KRaft) carries events between services. Rails produces tracker events through a transactional outbox and consumes raw vacancies with Karafka; Sidekiq stays for in-app background jobs.

Decisions worth a look:

- **Operations, not fat controllers.** Multi-step writes are `Dry::Operation` subclasses with a dry-validation contract; Grape endpoints only map results to HTTP. See `backend/app/domains/tracker/operations/record_application.rb`: validate, find-or-create company and vacancy, refuse duplicates, create the application and its first event, all in one transaction.
- **Two auth realms that never cross.** Admins use a Devise session for the Slim admin panel; portal users get a JWT from the Grape API with JTI revocation on logout.
- **Sandboxed code execution.** The `sandbox` compose service has no route out of its internal network, a read-only filesystem, no capabilities, CPU/memory/pid limits and no secrets: the app is mounted read-only with the master key blanked and credentials pointed at nothing. The Rails context talks to `sandbox_db`, a throwaway Postgres rebuilt on every start from `db/structure.sql` and seeded with invented data (`db/sandbox_seed.rb`), through a role that Postgres itself restricts to `SELECT` with a statement timeout. No real data ever reaches the sandbox. The Go supervisor enforces a shared token, a concurrency cap, the timeout (whole process group) and reports OOM kills distinctly; the API adds a per-user token-bucket rate limit (atomic Lua script in Redis) and a snippet size limit. See `services/sandboxd` and `backend/app/domains/playground`.
- **SQL schema dump.** `schema_format = :sql`, so partial indexes and FK rules survive round trips.
- **Transactional outbox for domain events.** Every tracker write appends an `outbox_events` row in the same transaction (`Tracker::Events`), and a Sidekiq relay (`Outbox::Jobs::PublishJob`, `FOR UPDATE SKIP LOCKED`) publishes it to `tracker.events` keyed by user. At-least-once delivery with an `event_id` for consumers to dedupe; a crash between the write and the publish can delay an event, never lose it.
- **Unreliable external APIs, contained.** `Aggregator::Clients::Hh` has explicit timeouts and typed errors; the operation turns them into a 503 without touching the database, and specs stub the HTTP with WebMock.
- **Idempotent ingestion.** `Aggregator::Operations::IngestPosting` consumes `vacancies.raw`: a replayed message only refreshes `last_seen_at`, postings from different boards for the same company and title merge into one vacancy, invalid payloads are skipped and logged, broker-level retries end in a dead-letter topic.
- **Shared sessions over ActionCable.** `?session=<token>` joins a `ConsoleSession`; the channel relays edits and run results to every subscriber, the JWT authenticates the WebSocket, and the same `Identity::Authenticate` serves both Grape and ActionCable.
- **Tests that do not touch the network.** WebMock stubs sandboxd; the Go supervisor is tested with `sh` instead of Ruby so the tests also run inside the image build.

## Stack

Ruby 4.0 · Rails 8.1 · PostgreSQL 18 · Redis 8 · Sidekiq 8 · Kafka 4 + Karafka 2.6 · Grape 4 · Devise 5 + devise-jwt · dry-operation / dry-validation / dry-monads · RSpec + FactoryBot + WebMock · React 19 · Vite 8 · TipTap 3 · CodeMirror 6 · @dnd-kit · Go 1.27

## Running locally

```bash
docker compose up
```

- Portal: http://localhost:5173
- Kafka from the host: localhost:29092 (topics are declared in `backend/karafka.rb` and created by the `karafka` service on start)
- API: http://localhost:3000/api/v1
- Admin panel: http://localhost:3000/admin

First run creates the database. Create an admin and sign up a portal user:

```bash
docker compose exec web bin/rails runner 'Admin.create!(email: "admin@example.com", password: "password123")'
curl -X POST localhost:3000/api/v1/signup -H 'Content-Type: application/json' \
     -d '{"email":"me@example.com","password":"password123"}'
```

The console's Rails context reads from `sandbox_db`, which is rebuilt with synthetic data on every `docker compose up`. To rebuild it by hand:

```bash
bin/sandbox-db-reset
```

The console is enabled in development only; set `PLAYGROUND_CONSOLE=true` to enable it elsewhere, and only behind the sandbox.

## Tests and checks

```bash
docker compose run --rm web bundle exec rspec     # backend specs
docker compose run --rm web bin/ci                # rubocop, bundler-audit, importmap audit, brakeman
cd services/sandboxd && go test ./...             # Go unit tests (also run during the image build)
```

## License

MIT, see [LICENSE](LICENSE).
