# Workflows Reference

Docs: [docs/workflows.md](../../docs/workflows.md).

Workflows compose ordered groups of tasks. A workflow is a `Task` subclass that `include`s `CMDx::Workflow`. Inputs, outputs, callbacks, middleware, retries, and settings all work the same as on a plain task.

## Setup

```ruby
class OnboardCustomer < CMDx::Task
  include CMDx::Workflow

  required :email, coerce: :string

  task ValidateIdentity
  task CreateAccount
  tasks SendWelcomeEmail, SendWelcomeSms, strategy: :parallel
end

OnboardCustomer.execute(email: "user@example.com")
```

Defining `def work` on a workflow raises `CMDx::ImplementationError` — `#work` is auto-generated to delegate to `Pipeline`.

## Groups

`task` / `tasks` (aliases) register one group per call. Groups run in declaration order and share the workflow's `context`.

### Options

| Option | Description |
|--------|-------------|
| `strategy:` | `:sequential` (default) or `:parallel`. |
| `pool_size:` | Parallel worker/fiber count. Defaults to `tasks.size`. |
| `executor:` | `:threads` (default), `:fibers`, or any callable matching `call(jobs:, concurrency:, on_job:)`. `:fibers` requires `Fiber.scheduler` to be installed. |
| `merge_strategy:` | `:last_write_wins` (default), `:deep_merge`, `:no_merge`, or a callable `call(workflow_context, result)`. Applied in declaration order over successful results only. |
| `fail_fast:` | When `:parallel`, short-circuit pending tasks on the first failure (in-flight tasks still finish). |
| `if:` / `unless:` | Gate the whole group. Signature `(workflow)` (Symbol → task method; Proc → `instance_exec`; `#call`-able → `callable.call(workflow)`). |

Every task class must be a `CMDx::Task` subclass — otherwise registration raises `TypeError`.

## Sequential groups

Default strategy. Each task runs in order on the shared context. The first `failed?` result halts the pipeline and propagates via `throw!`, failing the workflow. A `skipped?` result does **not** halt — the next task still runs.

```ruby
class ProcessOrder < CMDx::Task
  include CMDx::Workflow

  task ValidateOrder
  task ChargePayment
  task ShipOrder
end
```

## Parallel groups

Runs the group's tasks concurrently. Default backend is a native Ruby Thread pool.

```ruby
tasks SendReceipt, NotifyWarehouse, UpdateAnalytics,
  strategy: :parallel, pool_size: 3
```

Behavior:

- Each task receives `context.deep_dup` — mutations are isolated per worker.
- On success, each duplicated context is merged back into the workflow context.
- The first failed result halts the workflow; successful siblings still merge.
- Chain storage is propagated through fiber-local state so nested tasks see the same `CMDx::Chain`.

Because parallel tasks receive deep-duplicated contexts, a task that relies on mutations performed by a sibling in the same group will not see them. Split such dependencies into separate groups.

### Pluggable executors (`executor:`)

Swap the dispatch backend without changing the parallel semantics above:

```ruby
tasks A, B, C, strategy: :parallel, executor: :threads            # default
tasks A, B, C, strategy: :parallel, executor: :fibers, pool_size: 8
tasks A, B, C, strategy: :parallel, executor: ->(jobs:, concurrency:, on_job:) { MyPool.run(jobs, concurrency, &on_job) }
```

- `:threads` — `Queue`-backed worker pool sized by `pool_size || tasks.size`. No external deps.
- `:fibers` — one fiber per job via `Fiber.schedule`, bounded by `pool_size` via a `SizedQueue` semaphore. Raises `RuntimeError` unless `Fiber.scheduler` is installed on the current thread (e.g. inside `Async { ... }` from the `async` gem). The gem ships no scheduler — callers supply one.
- Callable — any object responding to `call(jobs:, concurrency:, on_job:)`. Must invoke `on_job.call(job)` per job and block until all finish. Cancellation, chain propagation, and context merging are owned by `on_job`; the executor only schedules.

Unknown executor symbols raise `ArgumentError` at execution time.

Executors are resolved from a per-task `CMDx::Executors` registry (duplicated from `CMDx.configuration.executors` on first access). Register custom backends by name once and reference them by symbol:

```ruby
class ApplicationTask < CMDx::Task
  register :executor, :bounded_pool, MyPool.method(:run)
end

# or globally
CMDx.configure { |c| c.executors.register(:bounded_pool, MyPool.method(:run)) }
```

### Merge strategies (`merge_strategy:`)

Controls how successful sibling contexts fold back into the workflow context. Fold order is always declaration order (deterministic, independent of completion order).

```ruby
tasks A, B, C, strategy: :parallel                           # :last_write_wins (default)
tasks A, B, C, strategy: :parallel, merge_strategy: :deep_merge
tasks A, B, C, strategy: :parallel, merge_strategy: :no_merge
tasks A, B, C, strategy: :parallel, merge_strategy: ->(ctx, result) { ctx[result.task.name] = result.context.to_h }
```

- `:last_write_wins` — shallow `Hash#merge!`; later-declared tasks overwrite earlier-declared on conflict. Matches previous behavior.
- `:deep_merge` — recursive over `Hash` values only; scalar-vs-hash still last-write-wins.
- `:no_merge` — the workflow context is not written to. Per-task results remain inspectable through `result.chain`.
- Callable — `call(workflow_context, result)` per successful result; failed results never reach the merger.

Unknown merge strategy symbols raise `ArgumentError`.

Merge strategies are resolved from a per-task `CMDx::Mergers` registry. Register custom named mergers via `register :merger, :name, callable` on a task class (or `CMDx.configuration.mergers.register(...)` globally) and reference them by symbol from `:merge_strategy`.

## Conditional groups

```ruby
task SetupBilling, if: :paid_plan?
task SendTrialEmail, unless: -> { context.plan == "enterprise" }
tasks NotifyOpsA, NotifyOpsB, strategy: :parallel, if: SupportGateCallback
```

## Nested workflows

Workflows are `Task` subclasses, so they compose as groups:

```ruby
class Onboard < CMDx::Task
  include CMDx::Workflow
  task Identity
  task BillingWorkflow   # another workflow
  task SendWelcome
end
```

Result chain analysis still works: `result.origin` walks back to the failing leaf, `result.caused_failure` and `result.threw_failure` identify the root cause vs. the re-thrower.

## Halt behavior

- The workflow halts on **the first `failed?` result only**.
- `skip!` never halts a workflow.
- The failed leaf's signal is re-thrown through the workflow via `throw!`, so the workflow's `result.reason`/`.metadata`/`.cause` mirror the originating task.
- There is no `breakpoints:` option.

## Rollback & compensation

Rollback is **per-task** — each task that defines `#rollback` gets called when that task itself fails. To compensate for **earlier successful tasks** in a failed workflow, use a workflow-level callback:

```ruby
class ProvisionTenant < CMDx::Task
  include CMDx::Workflow

  on_failed :tear_down

  task CreateSchema
  task SeedDefaults
  task ActivateBilling

  private

  def tear_down
    CleanupTenantJob.perform_later(result.context.tenant_id) if result.context.tenant_id
  end
end
```

## Inspecting results

```ruby
result = Onboard.execute(email: "x@y.com")

result.success?          # workflow-level status
result.origin            # leaf Result that actually failed
result.caused_failure    # first task in the chain whose rescue caused it
result.threw_failure     # last task that re-threw the signal

result.chain.size        # total Results in the chain (workflow + leaves)
result.chain.map(&:task) # [Onboard, ValidateIdentity, CreateAccount, ...]
```

## Invariants

- `def work` on a workflow → `CMDx::ImplementationError` at load time.
- Empty groups (`tasks` with no args inside a group block) → `ArgumentError` at execute time.
- Invalid `strategy:` → `ArgumentError`.
- Parallel groups cannot share mutable state via context mutations within the same group.
- Workflows inherit the parent class's pipeline via `dup` on inheritance.
