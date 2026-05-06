# Comparison

So you’re shopping for a “service object” style gem — nice. This page is a cheat sheet: **what CMDx packs in one box** versus a few popular friends, without the marketing fluff.

## The short story

CMDx tries to be the toolkit you reach for when you want **one place** for logging, telemetry, typed inputs, middleware, retries, and workflow-y execution — while keeping the runtime dependency list boring (mostly stdlib). Other gems are awesome too; they just optimize for different slices of that pie.

## Feature matrix (at a glance)

✅ = “ships with this idea.” ❌ = “not really a first-class thing here.”  
Use the table to answer: *“Do I care about this capability out of the box?”*

| Feature | [CMDx](https://github.com/drexed/cmdx) | [Actor](https://github.com/sunny/actor) | [Interactor](https://github.com/collectiveidea/interactor) | [ActiveInteraction](https://github.com/AaronLasseigne/active_interaction) | [LightService](https://github.com/adomokos/light-service) |
|---------|------|------------|------------|-------------------|--------------|
| Stdlib-only runtime deps | ✅ | ❌ | ✅ | ❌ | ❌ |
| Typed inputs | ✅ | ✅ | ❌ | ✅ | ❌ |
| Type coercion | ✅ | ❌ | ❌ | ✅ | ❌ |
| Input validation | ✅ | ✅ | ❌ | ✅ | ❌ |
| Built-in logging | ✅ | ❌ | ❌ | ❌ | ✅ |
| Telemetry hooks | ✅ | ❌ | ❌ | ❌ | ❌ |
| Middleware system | ✅ | ❌ | ❌ | ❌ | ✅ |
| Workflow execution | ✅ | ✅ | ✅ | ✅ | ✅ |
| Fault tolerance | ✅ | ❌ | ❌ | ❌ | ❌ |
| Lifecycle callbacks | ✅ | ✅ | ✅ | ✅ | ✅ |

## What you get “for free” with CMDx

- **Observability** — Structured logs and telemetry hooks are part of the design, not something you bolt on later after the third outage.

- **Timing on every run** — Each `Result` knows how long the task took (`duration`, in ms). The `:task_executed` telemetry event carries that too, so wiring metrics is usually a small subscriber — not a science project.

- **Inputs that behave** — Built-in coercers (think “string → integer”, dates, arrays, …) and validators (presence, length, format, …). Both are extensible if you outgrow the defaults.

- **Middleware** — Wrap the whole lifecycle (auth, caching, extra logging) without cramming everything into `work`.

- **Retries and faults** — Say `retry_on` with jitter when the network wobbles; use `success!` / `skip!` / `fail!` / `throw!` for clear outcomes instead of scattering magic return values.

- **Parallel workflows (when you need them)** — Workflow groups can run work in parallel using registered executors (`:threads`, `:fibers`, or your own) and merge context with registered mergers (`:last_write_wins`, `:deep_merge`, `:no_merge`, or custom). Details: [Workflows - Parallel Groups](workflows.md#parallel-execution).

- **Telemetry you can actually subscribe to** — Events like `:task_started`, `:task_deprecated`, `:task_retried`, `:task_rolled_back`, `:task_executed` only fire if someone is listening — no subscriber, no overhead.

- **No framework lock-in** — Rails, Hanami, Sinatra, or plain Ruby are all fine. Runtime deps stay small (`bigdecimal`, `logger`); you don’t need ActiveSupport just to exist.

If a row in the table made you go “wait, I need that,” follow the link to the gem that fits — and if several rows are ✅ for CMDx for *your* app, you might enjoy staying in one ecosystem.
