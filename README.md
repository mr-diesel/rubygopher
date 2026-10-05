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
| Live console | done | Run Ruby snippets from the browser, in plain Ruby or with the Rails app and models loaded. Both run in **sandboxd**, a Go service inside a locked-down container, against a read-only copy of the database |
| Application tracker | schema only | Companies, vacancies, applications, cold outreach and their event history. Next step: an API that lets an external AI assistant (ChatGPT, Claude) keep the journal for you via a personal token |
| Vacancy aggregator | schema only | Ruby/Go postings from hh.ru, getmatch and Habr Career, deduplicated into canonical vacancies with extracted skills. Planned as Go fetchers publishing to Kafka, consumed by Rails |
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
```

Decisions worth a look:

- **Operations, not fat controllers.** Multi-step writes are `Dry::Operation` subclasses with a dry-validation contract; Grape endpoints only map results to HTTP. See `backend/app/domains/identity/operations/sign_up.rb`.
- **Two auth realms that never cross.** Admins use a Devise session for the Slim admin panel; portal users get a JWT from the Grape API with JTI revocation on logout.
- **Sandboxed code execution.** The `sandbox` compose service has no route out of its internal network, a read-only filesystem, no capabilities, CPU/memory/pid limits and no secrets: the app is mounted read-only with the master key blanked and credentials pointed at nothing. The Rails context talks to `sandbox_db`, a copy of the development database, through a role that Postgres itself restricts to `SELECT` with a statement timeout. The Go supervisor enforces a shared token, a concurrency cap, the timeout (whole process group) and reports OOM kills distinctly; the API adds a per-user token-bucket rate limit (atomic Lua script in Redis) and a snippet size limit. See `services/sandboxd` and `backend/app/domains/playground`.
- **SQL schema dump.** `schema_format = :sql`, so partial indexes and FK rules survive round trips.
- **Tests that do not touch the network.** WebMock stubs sandboxd; the Go supervisor is tested with `sh` instead of Ruby so the tests also run inside the image build.

## Stack

Ruby 4.0 · Rails 8.1 · PostgreSQL 18 · Redis 8 · Sidekiq 8 · Grape 4 · Devise 5 + devise-jwt · dry-operation / dry-validation / dry-monads · RSpec + FactoryBot + WebMock · React 19 · Vite 8 · TipTap 3 · CodeMirror 6 · @dnd-kit · Go 1.27

## Running locally

```bash
docker compose up
```

- Portal: http://localhost:5173
- API: http://localhost:3000/api/v1
- Admin panel: http://localhost:3000/admin

First run creates the database. Create an admin and sign up a portal user:

```bash
docker compose exec web bin/rails runner 'Admin.create!(email: "admin@example.com", password: "password123")'
curl -X POST localhost:3000/api/v1/signup -H 'Content-Type: application/json' \
     -d '{"email":"me@example.com","password":"password123"}'
```

The console's Rails context reads from `sandbox_db`; fill it with a copy of your development data whenever you want it refreshed:

```bash
bin/sandbox-db-sync
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
