# Comparison

## Alternative Frameworks

CMDx bundles structured logging, telemetry hooks, type coercion, middleware, and retry/fault primitives into a single package with a stdlib-only runtime footprint. The table below maps feature coverage across the common service-object gems — use it to pick based on what you actually need, not on marketing.

| Feature                  | [CMDx](https://github.com/drexed/cmdx) | [Actor](https://github.com/sunny/actor) | [Interactor](https://github.com/collectiveidea/interactor) | [ActiveInteraction](https://github.com/AaronLasseigne/active_interaction) | [LightService](https://github.com/adomokos/light-service) |
| ------------------------ | -------------------------------------- | --------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------- |
| Stdlib-only runtime deps | ✅                                     | ❌                                      | ✅                                                         | ❌                                                                        | ❌                                                        |
| Typed inputs             | ✅                                     | ✅                                      | ❌                                                         | ✅                                                                        | ❌                                                        |
| Type coercion            | ✅                                     | ❌                                      | ❌                                                         | ✅                                                                        | ❌                                                        |
| Input validation         | ✅                                     | ✅                                      | ❌                                                         | ✅                                                                        | ❌                                                        |
| Built-in logging         | ✅                                     | ❌                                      | ❌                                                         | ❌                                                                        | ✅                                                        |
| Telemetry hooks          | ✅                                     | ❌                                      | ❌                                                         | ❌                                                                        | ❌                                                        |
| Middleware system        | ✅                                     | ❌                                      | ❌                                                         | ❌                                                                        | ✅                                                        |
| Workflow execution       | ✅                                     | ✅                                      | ✅                                                         | ✅                                                                        | ✅                                                        |
| Fault tolerance          | ✅                                     | ❌                                      | ❌                                                         | ❌                                                                        | ❌                                                        |
| Lifecycle callbacks      | ✅                                     | ✅                                      | ✅                                                         | ✅                                                                        | ✅                                                        |

**In the box:**

- **Observability** — structured logging, telemetry events, and chain-aware result tracking, no extra instrumentation required.
- **Per-execution timing** — every `Result` carries `duration` (milliseconds) and is emitted on the `:task_executed` telemetry event, so attaching a metrics exporter is a few lines.
- **Type system** — 13 built-in coercers (primitives, dates, arrays, hashes, etc.) and 7 validators (`absence`, `exclusion`, `format`, `inclusion`, `length`, `numeric`, `presence`), both pluggable.
- **Middleware** — wrap the task lifecycle for auth, caching, telemetry, etc., without touching `work`.
- **Retries and faults** — declarative `retry_on` with configurable jitter, halt primitives (`success!` / `skip!` / `fail!`), and `throw!` for propagating peer failures.
- **Pluggable parallelism** — workflow groups can run tasks concurrently using registered executors (`:threads`, `:fibers`, or custom) and fold results with registered mergers (`:last_write_wins`, `:deep_merge`, `:no_merge`, or custom). See [Workflows - Parallel Groups](https://drexed.github.io/cmdx/workflows/#parallel-execution).
- **Full telemetry surface** — `:task_started`, `:task_deprecated`, `:task_retried`, `:task_rolled_back`, and `:task_executed` events are emitted only when subscribers exist; subscribe from a single `CMDx.configure` block.
- **Framework agnostic** — runs under Rails, Hanami, Sinatra, or plain Ruby. Runtime deps are limited to `bigdecimal` and `logger`; no ActiveSupport requirement.
