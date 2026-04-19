# Comparison

## Alternative Frameworks

CMDx bundles structured logging, telemetry hooks, type coercion, middleware, and retry/fault primitives into a single package with a stdlib-only runtime footprint. The table below maps feature coverage across the common service-object gems — use it to pick based on what you actually need, not on marketing.

| Feature | [CMDx](https://github.com/drexed/cmdx) | [Actor](https://github.com/sunny/actor) | [Interactor](https://github.com/collectiveidea/interactor) | [ActiveInteraction](https://github.com/AaronLasseigne/active_interaction) | [LightService](https://github.com/adomokos/light-service) |
|---------|------|------------|------------|-------------------|--------------|
| Stdlib-only runtime deps | ✅ | ❌ | ✅ | ❌ | ❌ |
| Typed inputs | ✅ | ✅ | ❌ | ✅ | ❌ |
| Type coercion | ✅ | ❌ | ❌ | ✅ | ❌ |
| Input validation | ✅ | ✅ | ❌ | ✅ | ❌ |
| Built-in logging | ✅ | ❌ | ❌ | ❌ | ✅ |
| Telemetry hooks | ✅ | ❌ | ❌ | ❌ | ❌ |
| Runtime metrics | ✅ | ❌ | ❌ | ❌ | ❌ |
| Middleware system | ✅ | ❌ | ❌ | ❌ | ✅ |
| Workflow execution | ✅ | ✅ | ✅ | ✅ | ✅ |
| Fault tolerance | ✅ | ❌ | ❌ | ❌ | ❌ |
| Lifecycle callbacks | ✅ | ✅ | ✅ | ✅ | ✅ |

**What you get in the box:**

- **Observability** — structured logging, telemetry events, and chain-aware result tracking, no extra instrumentation required.

- **Type system** — 13 built-in coercers (primitives, dates, arrays, hashes, etc.) and 7 validators (`absence`, `exclusion`, `format`, `inclusion`, `length`, `numeric`, `presence`), both pluggable.

- **Middleware** — wrap the task lifecycle for auth, caching, telemetry, etc., without touching `work`.

- **Retries and faults** — declarative `retry_on` with configurable jitter, halt primitives (`success!` / `skip!` / `fail!`), and `throw!` for propagating peer failures.

- **Framework agnostic** — runs under Rails, Hanami, Sinatra, or plain Ruby. Runtime deps are limited to `bigdecimal` and `logger`; no ActiveSupport requirement.

## Event Sourcing Replacement

Full Event Sourcing requires an event store, snapshots, and rehydration logic. If you don't need strict replay guarantees, routing state changes through CMDx tasks and shipping the structured logs to a durable sink gets you most of the benefit for a fraction of the complexity.

CMDx supplies the structured payload; your log sink and retention policy supply the durability.

- **Audit trail** — every execution is logged with its inputs, status, and metadata, giving you a record of both intent (arguments) and outcome (status/reason).

- **Reconstructability** — because tasks capture all inputs required for an action, you can rebuild past state or replay logic by walking the log stream.

- **Simpler architecture** — keep the relational database for the read model and treat the log stream as the write model. You get CQRS-style separation without maintaining bespoke projections.
