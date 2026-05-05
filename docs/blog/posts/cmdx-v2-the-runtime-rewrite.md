---
date: 2026-05-13
authors:
  - drexed
categories:
  - Tutorials
slug: cmdx-v2-the-runtime-rewrite
---

# CMDx 2.0 Is Here: Rewriting the Runtime

v1 shipped in March 2025. Over the next year, a lot of real applications pushed it in directions I hadn't planned for: fiber-based schedulers, high-throughput workflows, middleware stacks that wanted to introspect results, pattern-matching consumers. Every one of those pressures exposed the same underlying problem — the v1 runtime was a state machine bolted onto a mutable `Result`, and the longer I tried to extend it, the more it fought back.

v2 is the rewrite those cracks justified. Same DSL surface you already know — `required`, `optional`, `returns`, `on_success`, `settings`, `CMDx::Workflow` — but a different engine underneath. This post is about why I rewrote the runtime, what actually changed, and how to get your app onto it.

<!-- more -->

## Why I Rewrote the Runtime

Four things kept biting me in v1:

1. **State-machine halts leaked control flow.** `fail!` didn't halt — it mutated `Result` state and returned. If you forgot to `return` on the next line, the task kept running with a failed result behind it. Real bugs, hard to spot in review.

2. **`Result` was mutable.** Any middleware, callback, or consumer could poke at `result.metadata[...] = ...` mid-execution. That made "what is the result right now?" a meaningless question and made it impossible to trust a result you received from somewhere else in the chain.

3. **`Thread.current[:cmdx_chain]` broke under fibers.** Anyone running CMDx inside `Async`, `async-job`, or Ruby 3.3's fiber scheduler could see chains leak between logically unrelated executions. Thread-local storage has outlived its usefulness in 2026 Ruby.

4. **The built-in middleware trio was load-bearing.** `Correlate`, `Runtime`, and `Timeout` were auto-registered. Half the users wanted them gone; the other half wanted different ones; nobody could swap them without fighting the registry. That's a sign the feature is in the wrong layer.

None of these are fixable with surface-level changes. They're runtime-shaped problems.

## The How: Signals, Immutable Results, Fiber-Local Chains

v2 pivots on three ideas. Everything else falls out from them.

### Halts Are Signals, Not State Mutations

```ruby
# v1 — fail! mutated result.state; code after it still ran
def work
  fail!("invalid email", code: :bad_input)
  deliver(context)  # v1 could still hit this
end
```

```ruby
# v2 — fail! throws a Signal; the next line is unreachable
def work
  fail!("invalid email", code: :bad_input)
  deliver(context)  # NEVER reached
end
```

Under the hood, `success!` / `skip!` / `fail!` / `throw!` now do `throw(Signal::TAG, signal)`. Runtime wraps `work` in a `catch(Signal::TAG) { ... }` and builds the final `Result` once, at the end, from whatever signal (or normal return) escaped. Halts terminate. The mental model matches what the word "halt" always suggested.

### Result Is Frozen at Construction

```ruby
result = MyTask.execute(...)

result.task.frozen?     #=> true
result.errors.frozen?   #=> true
result.context.frozen?  #=> true  (root only)
result.metadata[:x] = 1 #=> FrozenError
```

`Result` exposes no mutating API. All state lives in an embedded `Signal` — a frozen value object — built exactly once during `Runtime#finalize_result`. A `Result` you hold is the same `Result` everyone else holds. That's a prerequisite for every tool I wanted to add on top: pattern matching, telemetry subscribers, structured failure references, parallel workflow merges.

### Chain Is Fiber-Local

```ruby
# v1
Thread.current[:cmdx_chain]

# v2
Fiber[:cmdx_chain]
CMDx::Chain.current      # accessor
CMDx::Chain.clear        # cleared automatically on root teardown
```

`Chain` is now `Enumerable`, has a `Mutex` guarding `push` / `unshift`, and gets cleared when the outermost task finishes. Parallel workflow groups share the parent fiber's chain so every child result still correlates to the same `cid`.

## What You Write Differently

A condensed cheat sheet. The [full migration guide](https://drexed.github.io/cmdx/v2-migration/) has the rest.

| Area | v1 | v2 |
|---|---|---|
| Entry point | `MyTask.call` / `def call` | `MyTask.execute` / `def work` (old names aliased) |
| Inputs | `attribute :email, type: :string` | `input :email, coerce: :string` (`required` / `optional` unchanged) |
| Outputs | `returns :user` (presence only) | `output :user, default: ..., if: ...` (implicit required + optional defaults/guards) |
| Middleware | `def call(task, options, &block)` | `def call(task); yield; end` (one arg, must `yield`) |
| Built-in middlewares | `Correlate`, `Runtime`, `Timeout` auto-registered | removed — subscribe to Telemetry or register your own |
| Callbacks | `on_good`, `on_bad`, `on_executed` | `on_ok`, `on_ko` (`on_executed` removed) |
| Chain ID | `result.chain_id` | `result.cid` |
| Halt reach | code after `fail!` could still run | code after `fail!` is unreachable |
| Result mutability | mutable (`result.metadata[:x] = ...`) | frozen |
| Breakpoints | `task_breakpoints`, `workflow_breakpoints` | removed — `execute!` is strict mode |

If you're already on 1.21, you've done `def call` → `def work` already — v2 keeps the `.call` / `.call!` aliases so you can migrate module-by-module.

## New Capabilities You Didn't Have

### Telemetry pub/sub

Observability belongs out of the middleware stack. v2 ships a dedicated bus with five events that only fire when subscribed (zero cost otherwise):

```ruby
CMDx.configure do |config|
  config.telemetry.subscribe(:task_executed) do |event|
    StatsD.timing("cmdx.#{event.task_class}", event.payload[:result].duration)
  end

  config.telemetry.subscribe(:task_retried) do |event|
    Rails.logger.warn("retry #{event.payload[:attempt]} for #{event.task_class}")
  end
end
```

Events: `:task_started`, `:task_deprecated`, `:task_retried`, `:task_rolled_back`, `:task_executed`. Each event carries `cid`, `root`, `task_type`, `task_class`, `task_id`, `name`, `payload`, and `timestamp`.

### Parallel workflow groups

```ruby
class FanOutWorkflow < CMDx::Task
  include CMDx::Workflow

  task  LoadInvoice
  tasks ChargeCard, EmailReceipt,
        strategy:  :parallel,
        pool_size: 4
  task  FinalizeOrder
end
```

Workers `deep_dup` the workflow context, run in parallel, and merge successful child contexts back into the parent in declaration order. The first failed child halts the pipeline via `throw!`. Shared fiber-local chain — every worker shows up in `result.chain` under the same `cid`.

### `Task#rollback`

```ruby
class ChargeCard < CMDx::Task
  required :amount

  def work
    context.charge = Stripe::Charge.create!(amount: amount)
  end

  def rollback
    Stripe::Refund.create!(charge: context.charge.id) if context.charge
  end
end
```

Define `rollback` and Runtime calls it automatically on failure. Surfaces via `result.rolled_back?` and the `:task_rolled_back` Telemetry event. No more hand-rolling rescue/retry/refund ceremonies.

### Pattern matching on Result

```ruby
case result
in { status: "success" }                         then deliver(result.context)
in { status: "failed", metadata: { code: :rate_limited } } then schedule_retry
in { status: "failed", reason: }                 then alert(reason)
end
```

`Result` implements `deconstruct` and `deconstruct_keys`, so controllers and job handlers can dispatch on outcome without brittle `if result.success? && result.metadata[:code] == ...` ladders.

### Output verification

```ruby
# v1 — presence check only
returns :user, :token

# v2 — implicit required + optional default / :if / :unless guards
output :user
output :token, default: -> { JwtService.encode(user_id: context.user.id) }
```

Every declared output is implicitly required. Outputs verify each declared key on `task.context` after `work` succeeds: `:default` fills in `nil` values (and satisfies the check), and a missing key without a default records `outputs.missing` on `task.errors` and becomes a failed signal automatically. For coercion, transformation, or validation, use [Inputs](https://drexed.github.io/cmdx/inputs/definitions/) or post-`work` code.

## Performance

The rewrite wasn't a perf project, but the numbers came along for the ride: halts are roughly 2.5× faster, workflow failures ~3×, allocations down 50–80% depending on the workload. Full methodology and results in [`benchmark/RESULTS.md`](https://github.com/drexed/cmdx/blob/main/benchmark/RESULTS.md). Most of the allocation win is from not building intermediate `Result` objects during state transitions — there are no state transitions anymore.

## Upgrading

The [migration guide](https://drexed.github.io/cmdx/v2-migration/) is the single source of truth. Read it top-to-bottom — every section is a recipe you can apply independently, and there's an **Automated Migration Prompt** at the bottom that mechanizes most of the tedious parts if you feed it to an agent.

The minimum viable diff for most apps:

```ruby
# Gemfile
gem "cmdx", "~> 2.0"
```

Then, across your task classes:

- Rename `attribute :x, type: :string` → `input :x, coerce: :string`
- Rename `returns :user` → `output :user` (implicit required)
- Update middlewares from `call(task, options, &block)` to `call(task) { yield }`, and register instances (`register :middleware, Foo.new`) instead of classes
- Replace `result.chain_id` with `result.cid`, `result.good?` with `result.ok?`, `result.bad?` with `result.ko?`
- Drop `task_breakpoints` / `workflow_breakpoints` settings — use `execute!` where you want strict mode
- Re-register `Correlate` / `Runtime` / `Timeout` equivalents as Telemetry subscribers or custom middlewares (or delete them — `result.duration` is built in)

If the suite was green on 1.21, it will tell you exactly where each of these lives.

Happy coding!

## References

- [Upgrading from v1.x to v2.0](https://drexed.github.io/cmdx/v2-migration/)
- [CHANGELOG (2.0.0)](https://github.com/drexed/cmdx/blob/main/CHANGELOG.md)
- [Interruptions - Signals](https://drexed.github.io/cmdx/interruptions/signals/)
- [Outputs](https://drexed.github.io/cmdx/outputs/)
- [Configuration - Telemetry](https://drexed.github.io/cmdx/configuration/#telemetry)
- [Workflows](https://drexed.github.io/cmdx/workflows/)
- [Benchmarks](https://github.com/drexed/cmdx/blob/main/benchmark/RESULTS.md)
