# Architecture decisions

Short records of the choices that shaped the codebase: the context, what was chosen, what it costs. Newest last.

## 1. Business logic in Dry::Operation, not in controllers or models

**Context.** Recording an application is six steps with three failure modes (invalid input, duplicate, upstream down), and the Grape endpoint, the MCP tool and specs all need the same flow.

**Decision.** Every multi-step write is a `Dry::Operation` subclass with a dry-validation contract. `call` lists the happy path through `step`; steps return `Success`/`Failure` and the first failure halts the flow; multi-row writes run inside `transaction { }`. Failures are `[kind, payload]` tuples that the transport maps to HTTP (422/409/404/503) or to an MCP error result.

**Consequences.** Endpoints are ten lines. The same operation serves REST, MCP and consumers. The cost is one more file per use case and the `require "dry/operation/extensions/active_record"` line at the top of each operation, because the gem does not autoload its extensions.

**Rejected.** dry-transaction (deprecated), service objects without a result type (every caller re-invents error handling), callbacks (side effects hidden in the model).

## 2. Grape API with three kinds of credentials

**Context.** Three clients with different trust: an admin editing shared content, a portal user, and an AI assistant acting for that user from a browser.

**Decision.** Admins use a Devise session on server-rendered pages. Portal users get a JWT with JTI revocation (logout invalidates every issued token). Assistants use a personal `rg_` token stored with deterministic Active Record Encryption, so it is still a lookup key but unreadable in a dump. One `Identity::Authenticate` serves Grape and ActionCable and reports which credential was used; token management requires a portal session, so a leaked token cannot rotate or revoke itself.

**Consequences.** No crossing between realms by construction. The MCP endpoint takes the token in the URL, which is what browser connectors can send; the URL is therefore a secret and the portal says so.

## 3. Kafka between Rails and Go, Sidekiq kept for in-app work

**Context.** The fetchers and the notifier are Go processes that must not depend on the Rails database. In-app background work (reminders, outbox sweep, skill extraction) has no such constraint.

**Decision.** Kafka (single-node KRaft, Karafka in Rails, franz-go in Go) carries messages between processes: `vacancies.raw` in, `tracker.events` out, `telegram.links` back. Sidekiq with sidekiq-cron runs the in-app jobs. Topics are declared in `karafka.rb` and created by a migration command; auto-creation is off.

**Consequences.** Two queues to operate. In exchange the Go services are replaceable and testable without Rails, and partitioning by user keeps per-user ordering.

**Rejected.** RabbitMQ (fine for work queues, weaker story for replayable event logs); calling Rails HTTP endpoints from Go (couples the services to the app's availability); Sidekiq only (Go workers would need Redis protocol compatibility with Sidekiq's job format).

## 4. Transactional outbox for domain events

**Context.** An application is recorded and a Telegram message must follow. Publishing to Kafka inside the request either loses the message when the broker is down or publishes for a transaction that then rolls back.

**Decision.** The operation writes an `outbox_events` row in the same transaction as the change. An `after_commit` enqueues a Sidekiq relay that drains unpublished rows in id order under `FOR UPDATE SKIP LOCKED`, produces them synchronously and stamps `published_at`; a cron sweep catches rows whose enqueue was lost. Every message carries an `event_id` so consumers can dedupe.

**Consequences.** At-least-once, never lost, slightly delayed under failure. Consumers must be idempotent; the Go notifier keeps a bounded set of seen ids.

## 5. Sandbox: a Go supervisor in a container that can reach nothing

**Context.** The portal runs user-written Ruby and Go. The app's own process, credentials and database must stay out of reach.

**Decision.** `sandboxd` runs in a compose service on an internal network with no gateway, a read-only filesystem, all capabilities dropped, CPU/memory/pid limits and no secrets: the app is bind-mounted read-only with the master key replaced by `/dev/null`. The Rails context talks to `sandbox_db`, a throwaway Postgres rebuilt on every start from `db/structure.sql` and seeded with invented data, through a role Postgres restricts to `SELECT` with a statement timeout. The supervisor enforces a shared token, a concurrency cap, per-snippet timeouts on the whole process group and an output cap; Rails adds a per-user token-bucket rate limit (atomic Lua script in Redis) and a snippet size limit.

**Consequences.** Real data never reaches the sandbox, so a sandbox escape yields invented rows and no secrets. Boot of the Rails context costs ~0.5 s with a warm bootsnap cache. The per-snippet memory limit inside the container is the cgroup, not an rlimit.

**Rejected.** Forking the Puma worker (same process tree, same credentials), a managed code-execution API (the point was to show the containment).

## 6. SQL schema dump

**Decision.** `schema_format = :sql`. Partial indexes (`WHERE skills_extracted_at IS NULL`), column comments and FK rules survive round trips; `schema.rb` would drop them. The dev image installs `postgresql-client-18` from PGDG because the dump must be written by a `pg_dump` matching the server.

## 7. Idempotent ingestion keyed by board id

**Decision.** `IngestPosting` is keyed by (`source`, `external_id`): a replayed message refreshes `last_seen_at` and the tags, never duplicates. Postings from different boards merge into one vacancy by company and case-insensitive title. Invalid payloads are logged and skipped; everything else raises into Karafka's retries and ends in a dead-letter topic. No dedupe cache in the fetcher on purpose: republishing is how `last_seen_at` stays fresh, and a nightly job closes postings nobody has shown for a week.

## 8. Skills from a dictionary, interviews from a prompt: no LLM in the backend

**Context.** Both tagging vacancies and running a mock interview look like LLM jobs. A paid API would add keys, billing, latency and a vendor to a portfolio project.

**Decision.** Skills come from a seeded dictionary (`db/seeds.rb`, names + aliases) matched as whole words; two-letter names are matched case-sensitively. The interview is a prompt the backend assembles from the vacancy, the résumé, the gap between them and the application history; the user pastes it into any chat, or an MCP client runs it as the `mock_interview` prompt and saves the verdict back as a note.

**Consequences.** Deterministic, testable with RSpec, free. The matcher cannot tell "required" from "nice to have"; the interview quality is whatever assistant the user brings.

## 9. One query object behind three transports

**Decision.** The portal, the REST API and the MCP tools call the same query objects (`Aggregator::Queries::Feed`, `Tracker::Queries::Digest`, `Tracker::Queries::Funnel`) and render the same Grape entities. A new filter in the feed appears everywhere at once, and what a human sees matches what an assistant sees by construction.

## 10. Kubernetes manifests as a kustomize base with a minikube overlay

**Decision.** A plain kustomize base (StatefulSets for Postgres, Redis, Kafka; a `migrate` Job; Deployments; one Ingress) and an overlay that swaps images and secrets for minikube, so the manifests are verified by actually running them. Web pods skip `db:prepare` (`SKIP_DB_PREPARE`) because the Job owns migrations and two replicas must not race on a fresh database.

**Lessons from the first run.** An overlay's `images:` must name the image the base already substituted, not the bare name. A headless Service for a single-node KRaft broker needs `publishNotReadyAddresses: true`, or the broker cannot resolve its own name before it is ready. A Job's template is immutable, so it is deleted before each apply.

**Rejected.** Helm (a chart for one deployment is ceremony); Kamal (fits one host, not the multi-process layout).
