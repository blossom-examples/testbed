# Blossom Testbed

A small Rails application for measuring real deployment behavior: HTTP,
private API calls, ActionCable, PostgreSQL, Solid Queue and synthetic jobs.
It contains no Platform business logic or customer data.

## Services

| Service | Replicas | Command | Port | Routing |
| --- | ---: | --- | ---: | --- |
| web | 2 | `bin/web` | 3000 | Public default |
| api | 2 | `bin/api` | 3220 | Public `/api`; also called privately by web |
| cable | 2 | `bin/cable` | 3120 | Public `/cable` |
| worker | 2 | `bin/worker` | — | Private |
| scheduler | 1 | `bin/scheduler` | — | Private |

Use 1 vCPU / 1.75 GB per replica for the Platform comparison. Configure
`/ready` as an HTTP readiness check with traffic protection on web, api and
cable. Use `bin/rails db:prepare` as the release hook when preparing fresh
fixture databases or applying schema changes. For a retained fixture whose
schema is already prepared, disable its Release Phase in Blossom during warm
routing benchmarks. This also skips the temporary release endpoint's network
preparation and cleanup. Re-enable it before deploying schema changes; keep
the Procfile entry for fresh deployments. Do not run migrations in each
Service's startup command. Keep automated deploys off during benchmarks.

Every HTTP process runs the same app. Add a normal Environment domain, without
a Service override, for the dashboard and benchmark entry point. Generated
Service URLs force all paths to that Service: the generated web URL cannot
exercise the separate API and Cable Services. On the Environment domain,
explicit paths exercise distinct public Services; `GET /private` on web exercises the API's private endpoint.

## Configuration

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | Testbed's own primary PostgreSQL database |
| `QUEUE_DATABASE_URL` | Testbed's own Solid Queue database |
| `REDIS_URL` | Testbed's own Redis instance for ActionCable |
| `SECRET_KEY_BASE` | Random Rails secret; runtime only |
| `TESTBED_TOKEN` | Random bearer token, at least 32 bytes; runtime only |
| `RELEASE_ID` | Controlled release label, such as `baseline-1` |
| `PRIVATE_API_URL` | Private API base URL, including port 3220 |
| `RAILS_ENV` | `production` when deployed |
| `RAILS_MAX_THREADS` | 5 by default |
| `DATABASE_POOL` | 10; includes Solid Queue housekeeping connections |
| `WEB_CONCURRENCY` | 0 by default: one Puma process, five threads |
| `READY_DELAY_SECONDS` | Optional startup delay, bounded to 0–120 seconds |
| `READY_MODE` | `fail` deliberately refuses readiness |

Use Environment Links for database and Redis URLs. The databases must belong
to Testbed, never another app's namespace. They can run on separate engines
or separate namespaces of a Testbed-owned engine; record which was measured.
Store secrets outside Git and inject them at runtime. Builds use
`SECRET_KEY_BASE_DUMMY=1` for asset compilation; they need no live credentials.

For a private API URL on Blossom, use the API Service and Environment IDs:

    http://service-EXAMPLE.environment-EXAMPLE.blossom.internal:3220

The dashboard holds the token in memory only. It is never stored in browser
storage or included in a URL. Reads expose only synthetic counts and replica
identity. Writes fail closed when no sufficiently long token is configured.
Use a test deployment; this app intentionally exposes diagnostic endpoints.

## Local development

Start PostgreSQL and Redis on local ports. Export the three connection URLs
above, then:

    bundle install
    bin/rails db:prepare
    bin/web

In separate terminals with the same environment:

    bin/worker
    bin/scheduler

The single local web process also serves `/api` and `/cable`. Set
`PRIVATE_API_URL=http://127.0.0.1:3220` and run `bin/api` to exercise the
separate private API process. Use isolated databases for tests:

    RAILS_ENV=test bin/rails db:prepare
    bin/rails test
    standardrb

## Probes and workload

| Endpoint | Behavior |
| --- | --- |
| `GET /up` | Liveness and release/Service/replica identity |
| `GET /ready` | Checks primary DB, queue DB, Redis and startup controls |
| `GET /qa`, `GET /api/status` | Identity, total jobs, completed jobs and effects |
| `GET /private` | Makes a bounded private API request from web |
| `GET /slow?seconds=5` | Bounded 0–30 second response for drain checks |
| `GET /api/jobs/:request_key` | Authenticated job completion and effect evidence |
| `POST /api/jobs` | Authenticated synthetic work, at most one second per job |
| `WS /cable` | ActionCable `EventsChannel`: connection and completion events |

A job request has `request_key` (1–100 letters, digits, `_` or `-`) and optional
`duration_ms` (integer 0–1000, default 50). Send the bearer token in the
Authorization header. Retrying an identical key reuses its WorkItem; changing
its duration is a conflict. Workers lock each WorkItem and commit one effect.
A crash before commit can repeat computation, but cannot commit two effects.

The scheduler adds one heartbeat per UTC minute. Each heartbeat reconciles up
to 100 unfinished WorkItems from the past day, closing the primary/queue
transaction gap. Duplicate queue deliveries are safe. Redis broadcasts are
best effort: after reconnecting, reconcile counts through `/qa`; a missed
WebSocket event does not mean a job was lost. Job records remain for inspection;
use a fresh fixture database for a new campaign rather than silently purging it.

Compare unchanged-source warm redeploys separately from builds, cold Server
provisioning and fault cases. Keep desired replica counts, health checks,
resources, dependencies and capacity settings fixed within a comparison.
Release labels identify transitions; replica hostnames reveal moves within
the same release. Rails boot and exit timestamps appear in each Service log.

Benchmark collectors belong in Blossom QA, outside this app. Never add
provider credentials, arbitrary command execution, customer data or routing
algorithms to the fixture.
