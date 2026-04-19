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
| `pool_size:` | Parallel worker thread count. Defaults to `tasks.size`. |
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

Runs the group's tasks concurrently on a Thread pool.

```ruby
tasks SendReceipt, NotifyWarehouse, UpdateAnalytics,
  strategy: :parallel, pool_size: 3
```

Behavior:

- Each task receives `context.deep_dup` — mutations are isolated per thread.
- On success, each duplicated context is merged back into the workflow context.
- The first failed result halts the workflow; successful siblings still merge.
- Chain storage is propagated through fiber-local state so nested tasks see the same `CMDx::Chain`.

Because parallel tasks receive deep-duplicated contexts, a task that relies on mutations performed by a sibling in the same group will not see them. Split such dependencies into separate groups.

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
