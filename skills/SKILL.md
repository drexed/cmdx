---
name: cmdx
description: Build, debug, and document CMDx tasks and workflows in Ruby. Use when creating service/command objects with CMDx, composing tasks into workflows, handling halts and faults, or wiring inputs, outputs, callbacks, middleware, retries, and configuration. Don't use for generic Ruby refactors, Rails controller work, or non-CMDx service objects.
---

# CMDx Agent Skill

CMDx is a Ruby framework for composable command/service objects with declarative inputs, outputs, coercion, validation, retries, rollback, and structured observability. Deep dives live under [docs/](docs/) and [references/](references/); the [LLM index](https://drexed.github.io/cmdx/llms.txt) bundles the full doc tree for one-shot loading.

## Lifecycle

Every task runs through `CMDx::Runtime` in this order:

1. **Middlewares** wrap everything (`call(task) { yield }` chain).
2. **Deprecation** check (may block or log).
3. **`before_execution` callbacks**.
4. **`before_validation` callbacks**.
5. **Input resolution** — fetch, coerce, transform, validate.
6. **`work`** runs inside `catch(CMDx::Signal::TAG)`, wrapped in `retry_on`.
7. **Output verification** — coerce/validate declared outputs.
8. **`rollback`** runs if the signal is `failed` and the task defines `#rollback`.
9. **State callbacks** — `on_complete` or `on_interrupted`.
10. **Status callbacks** — `on_success` / `on_skipped` / `on_failed`.
11. **Outcome callbacks** — `on_ok` (success or skipped) or `on_ko` (skipped or failed).
12. **Result finalize + teardown** — task, errors, and root context are frozen; chain is cleared.

`success!` / `skip!` / `fail!` / `throw!` are control-flow tokens that `throw` a `CMDx::Signal` caught by Runtime — anything after a halt is unreachable. They only work inside the signal catch (input resolution, `work`, output verification); calling them from `before_execution` / `before_validation` callbacks or middleware bubbles past Runtime and never produces a `Result`. See [docs/basics/setup.md](docs/basics/setup.md) for the full state diagram.

## DSL Surface

| Category | Keywords |
|----------|----------|
| Inputs | `required`, `optional`, `input`, `inputs` |
| Outputs | `output`, `outputs` |
| Callbacks | `before_execution`, `before_validation`, `on_success`, `on_skipped`, `on_failed`, `on_complete`, `on_interrupted`, `on_ok`, `on_ko` |
| Class config | `settings`, `retry_on`, `deprecation`, `register`, `deregister` |
| Halts (inside `work`) | `success!`, `skip!`, `fail!`, `throw!` |
| Workflow | `include CMDx::Workflow`, `task`, `tasks` |
| Execution | `Task.execute`, `Task.execute!` (aliased `call` / `call!`) |

## Minimal Task

```ruby
class Greet < CMDx::Task
  required :name, presence: true

  def work
    context.greeting = "Hello, #{name}!"
  end
end

result = Greet.execute(name: "World")
result.success?           #=> true
result.context.greeting   #=> "Hello, World!"

# Block form returns the block's value.
Greet.execute(name: "World") { |r| r.context.greeting }  #=> "Hello, World!"
```

## Realistic Task

```ruby
class ProcessPayment < CMDx::Task
  settings(tags: ["billing"])

  retry_on Gateway::TimeoutError, limit: 3, jitter: :exponential

  before_execution :find_order
  on_success :send_receipt

  required :order_id, coerce: :integer
  required :amount,   coerce: :big_decimal, numeric: { gt: 0 }
  optional :currency, coerce: :string, default: "USD", inclusion: { in: %w[USD EUR GBP] }

  output :charge_id
  output :receipt_url

  def work
    charge = Gateway.charge!(amount: amount, currency: currency)
    context.charge_id   = charge.id
    context.receipt_url = charge.receipt_url
  end

  def rollback
    Gateway.refund!(context.charge_id) if context.charge_id
  end

  private

  def find_order
    @order = Order.find(order_id)
    fail!("Order already paid") if @order.paid?
  end

  def send_receipt
    ReceiptMailer.send(@order, context.receipt_url).deliver_later
  end
end
```

## Inputs

Declare with `input` / `inputs` / `required` / `optional`. Each generated reader returns the coerced, transformed, validated value — read it instead of `context.<name>`, which still holds the raw input.

Pipeline per input: **Source → Default → Coerce → Transform → Validate**.

```ruby
class Example < CMDx::Task
  required :email, coerce: :string, format: { with: URI::MailTo::EMAIL_REGEXP }
  optional :role,  coerce: :string, default: "member", inclusion: { in: %w[admin member guest] }
  input    :notes                                          # optional by default

  def work
    email   # coerced/validated
    role
    notes
  end
end
```

**Coercions** accept a Symbol, an Array (tried in order, first success wins), a Hash (per-coercion options), or any inline `#call(value, task)`-able. Built-ins: `:array`, `:big_decimal`, `:boolean`, `:complex`, `:date`, `:date_time`, `:float`, `:hash`, `:integer`, `:rational`, `:string`, `:symbol`, `:time`.

```ruby
required :count,       coerce: :integer
required :value,       coerce: %i[rational big_decimal]
required :recorded_at, coerce: { date: { strptime: "%m-%d-%Y" } }
```

**Validators** — shorthand keys: `presence:`, `absence:`, `format:`, `length:`, `numeric:`, `inclusion:`, `exclusion:`, plus inline `validate:`. Numeric/length option keys: `:min`/`:gte`, `:max`/`:lte`, `:gt`, `:lt`, `:within`/`:in`, `:not_within`/`:not_in`, `:is`/`:eq`, `:is_not`/`:not_eq`.

```ruby
required :age,  coerce: :integer, numeric: { gt: 0, lt: 150 }
required :code, coerce: :string,  length: { is: 6 }, format: { with: /\A[A-Z0-9]+\z/ }
optional :tags, coerce: :array,   length: { max: 10 }
```

**Naming** — `as:`, `prefix:`, `suffix:` rename the generated reader.

```ruby
input :template,     prefix: true        # context_template
input :format,       prefix: "report_"   # report_format
input :branch,       suffix: true        # branch_context
input :scheduled_at, as: :scheduled      # scheduled
```

**Sources & transforms**:

```ruby
input :rate,  source: :current_rate                 # task instance method
input :token, source: TokenGenerator                # #call(task)
input :email, transform: :downcase
input :score, coerce: :integer, transform: proc { |v| v.clamp(0, 100) }
```

Full reference: [references/inputs.md](references/inputs.md).

## Outputs

Declare keys the task must write to `context`. Verification runs after `work` succeeds (skipped when `work` halted).

```ruby
class CreateUser < CMDx::Task
  required :email, coerce: :string

  output :user
  output :token

  def work
    context.user  = User.create!(email: email)
    context.token = JwtService.encode(user_id: context.user.id)
  end
end
```

Every declared output is implicitly required. Outputs support `default:`, `if:`/`unless:`, and `description:` only. A missing output fails the task with `result.errors[name]`. For coercion, transformation, or validation use inputs (or write derived values directly inside `work`).

Full reference: [references/outputs.md](references/outputs.md).

## Workflows

Compose tasks by including `CMDx::Workflow` in a `Task` subclass. Defining `#work` on a workflow raises `CMDx::ImplementationError`.

```ruby
class OnboardCustomer < CMDx::Task
  include CMDx::Workflow

  required :email, coerce: :string

  task ValidateIdentity
  task CreateAccount
  task SetupBilling, if: :billing_required?
  tasks SendWelcomeEmail, SendWelcomeSms, strategy: :parallel

  private

  def billing_required?
    context.plan != "free"
  end
end
```

- All tasks share one `Context`.
- The workflow halts on the **first `failed?` result**. Skipped tasks never halt.
- Group options: `strategy:` (`:sequential` default, or `:parallel`), `pool_size:`, `if:` / `unless:`.
- Parallel groups deep-dup context per task and merge back on success only; the failed leaf propagates via `throw!`.

Full reference: [references/workflows.md](references/workflows.md).

## Halting

All halt methods `throw` out of `work` — they never return.

```ruby
def work
  success!("Imported #{n} rows", rows: n)       # complete + success (with annotation)
  skip!("Already processed")                    # interrupted + skipped
  fail!("Not found", code: "NOT_FOUND")         # interrupted + failed
  throw!(InnerTask.execute(context))            # re-throws if inner failed (no-op otherwise)
end
```

Signatures: `success!` / `skip!` / `fail!` take `(reason = nil, **metadata)`. `throw!` takes `(other_result, **metadata)` and is a no-op unless `other_result.failed?`.

Accumulating errors via `task.errors.add(:attr, "msg")` triggers an automatic fail after `work` — no explicit `fail!` needed. The fail reason is `errors.to_s` (full messages joined with `". "`).

Full reference: [references/interruptions.md](references/interruptions.md).

## Faults

`execute` always returns a `Result`. `execute!` raises `CMDx::Fault` on `failed?` results (skip does not raise) and re-raises the original `StandardError` when `result.cause` was a non-Fault exception.

```ruby
begin
  MyTask.execute!(data: input)
rescue CMDx::Fault.for?(PaymentTask, BillingTask) => e
  e.result        # the originating Result (walks origin to the leaf)
  e.task          # the failing Task class
  e.context       # frozen context
  e.chain         # full CMDx::Chain
  e.message       # result.reason (or localized "unspecified")
rescue CMDx::Fault.matches? { |f| f.result.metadata[:critical] } => e
  escalate(e)
end
```

## Result

```ruby
result = MyTask.execute(input: data)

# States: "complete" or "interrupted"
result.state        #=> "complete"
result.complete?    #=> true
result.interrupted? #=> false

# Statuses: "success", "skipped", "failed"
result.status       #=> "success"
result.success?     #=> true
result.ok?          #=> true   (success OR skipped — "not failed")
result.ko?          #=> false  (skipped OR failed — "not success")

# Data
result.context      # shared Context (frozen on root teardown)
result.errors       # CMDx::Errors map
result.reason       # reason string from success!/skip!/fail! (nil when unset)
result.metadata     # frozen hash
result.cause        # rescued StandardError (or nil)
result.origin       # upstream Result this was echoed from (or nil)
result.retries      # Integer
result.duration     # Float ms

# Handlers — chainable, block required
result
  .on(:success) { |r| redirect_to(dashboard_path) }
  .on(:failed)  { |r| render_error(r.reason) }
  .on(:skipped) { |r| log_skip(r.reason) }

# Pattern matching
# deconstruct: [type, task, state, status, reason, metadata, cause, origin]
case result
in ["Task", _, "complete",    "success", *]         then handle_success
in ["Task", _, "interrupted", "failed",  reason, *] then handle_failure(reason)
end

case result
in { status: "failed", metadata: { retryable: true } } then schedule_retry
in { state: "complete", status: "success" }            then celebrate
end
```

Full reference: [references/result.md](references/result.md).

## Callbacks

Declare via the per-event DSL helpers (`before_execution`, `before_validation`, `on_success`, `on_skipped`, `on_failed`, `on_complete`, `on_interrupted`, `on_ok`, `on_ko`). Each accepts a method name (Symbol), a Proc/lambda (`instance_exec`'d on the task with `task` passed as the block arg, so `->(task) { ... }` is the canonical shape), or a `#call(task)`-able. All forms support `if:` / `unless:` gates. The underlying form is `register :callback, event, callable, **opts`.

```ruby
class Example < CMDx::Task
  before_execution  :init_tracking
  before_validation :normalize_input
  on_success :notify, if: -> { context.notify? }
  on_failed  LogFailureCallback
  on_complete ->(task) { Audit.log(task.class.name) }
end
```

The `Result` isn't built yet when callbacks run — read `task.context` / `task.errors` inside, or subscribe to the `:task_executed` telemetry event for finalized result data.

## Middleware

Wraps the entire lifecycle. Interface: `call(task) { yield }` (or `&next_link` for Procs). Must yield or `CMDx::MiddlewareError` is raised.

```ruby
class AuditMiddleware
  def call(task)
    AuditLog.start(task.class.name)
    yield
  ensure
    AuditLog.finish(task.class.name)
  end
end

class MyTask < CMDx::Task
  register :middleware, AuditMiddleware.new
  register :middleware, ->(task, &next_link) {
    task.metadata[:tracked] = true
    Timer.track(task.class) { next_link.call }
  }
  register :middleware, OuterMiddleware, at: 0   # insert at index
end
```

No middleware ships with the gem — pass instances (or classes responding to `#call(task)`) you author yourself. See [docs/middlewares.md](docs/middlewares.md).

## Retries

```ruby
class Fetch < CMDx::Task
  retry_on Net::OpenTimeout, Net::ReadTimeout,
    limit: 3, delay: 0.5, max_delay: 5.0, jitter: :exponential

  retry_on Api::Throttled, limit: 5 do |attempt, delay|
    delay * (attempt + 1)
  end
end
```

- Only retries when the exception matches `retry_on`. Anything else (or a matching exception after the limit) becomes a failed result with `result.cause` set.
- Jitter strategies: `:exponential`, `:half_random`, `:full_random`, `:bounded_random`, a Symbol (task method), a Proc (`instance_exec(attempt, delay)`), or any `#call(attempt, delay)`-able.
- Only `work` is retried — inputs, outputs, and callbacks run once. `task.errors` accumulates across attempts; clear it at the start of `work` if you re-populate per attempt.

Inspect with `result.retries` / `result.retried?`. Docs: [docs/retries.md](docs/retries.md).

## Rollback

Define `#rollback` to undo side effects. Runtime calls it after `work` when the signal is `failed` (before completion callbacks) and flags `result.rolled_back?`.

```ruby
class ChargeCard < CMDx::Task
  def work
    context.charge = Gateway.charge!(context.amount)
  end

  def rollback
    Gateway.refund!(context.charge.id) if context.charge
  end
end
```

Rollback is **per-task**. To compensate across a workflow's earlier successful tasks, use an `on_failed` callback on the workflow class.

## Context

```ruby
context[:key]                    # read
context.key                      # read (method_missing; nil when absent)
context.key = value              # write
context.store(:key, value)       # explicit write
context.merge(hash)              # mutate in place; returns self
context.fetch(:key, default)     # Hash#fetch semantics
context.retrieve(:key) { v }     # fetch-or-store
context.key?(:key)               # existence
context.dig(:a, :b, :c)          # nested read
context.delete(:key)             # remove
```

`Context` is frozen on root teardown — post-execution mutations raise `FrozenError`. Nested tasks share the same context object unless isolated via `context.deep_dup` (parallel workflow groups do this automatically).

## Configuration

`CMDx.configure` sets framework-wide defaults; `settings(...)` overrides per-class logger / formatter / level / backtrace cleaner / tags; everything else uses dedicated DSL.

```ruby
CMDx.configure do |config|
  config.default_locale = "en"
  config.logger         = Logger.new($stdout)
  config.log_formatter  = CMDx::LogFormatters::JSON.new

  config.middlewares.register MyGlobalMiddleware
  config.callbacks.register   :on_failed, ErrorTracker
  config.coercions.register   :money,   MoneyCoercion
  config.validators.register  :api_key, ApiKeyValidator
  config.telemetry.subscribe(:task_executed) { |event| ... }
end

class MyTask < CMDx::Task
  settings(tags: ["critical"], log_level: Logger::DEBUG)

  retry_on Net::OpenTimeout, limit: 3
  deprecation :warn, if: -> { Rails.env.production? }

  register :middleware, TimingMiddleware.new
  register :validator,  :api_key, ApiKeyValidator
end
```

Full reference (registry matrix, telemetry events, Rails wiring): [references/configuration.md](references/configuration.md).

## Exceptions

Flat hierarchy rooted at `CMDx::Error` (aliased `CMDx::Exception`):

```
StandardError
└── CMDx::Error
    ├── CMDx::DefinitionError      # input name collides with existing method
    ├── CMDx::DeprecationError     # deprecation :error was triggered
    ├── CMDx::ImplementationError  # missing #work, or #work defined on a Workflow
    ├── CMDx::MiddlewareError      # middleware didn't yield
    └── CMDx::Fault                # raised by execute! on failed? results
```

`CMDx::Error` subclasses other than `Fault` propagate through `execute` unconverted — they indicate framework misuse, not runtime failure.

## Common Pitfalls

### 1. Forgetting `def work`

Raises `CMDx::ImplementationError` at execution time from both `execute` and `execute!`.

### 2. Reading `context.foo` instead of the generated reader

```ruby
# Wrong: bypasses coercion/validation — returns the raw input
def work
  context.email
end

# Right: use the generated reader
required :email, coerce: :string
def work
  email
end
```

Coerced input values live on the task instance, not on `context`. To persist them, write back explicitly (`context.email = email`).

### 3. Input declaration order

Inputs are resolved in declaration order. If one input references another via `source:` or an `if:` predicate, declare the referenced input first.

### 4. Middleware that forgets to yield

Silently swallowing `yield` raises `CMDx::MiddlewareError` outside the signal catch — the failure is not convertible to a result. Always yield (or `next_link.call`) on every code path, including `rescue` / `ensure`.

### 5. Mutating the root context after teardown

Runtime freezes the root context, task, errors, and chain during teardown. Post-execution writes raise `FrozenError`. Use `context.deep_dup` before teardown when you need a mutable snapshot.

### 6. Assuming workflows halt on skip

Workflows halt only on `failed?`. Skipped tasks are no-ops; the pipeline continues. To make a step hard-fail, call `fail!` (not `skip!`).

### 7. `execute!` doesn't always raise `Fault`

When `result.cause` is a non-`Fault` `StandardError` (e.g. an `ActiveRecord::RecordNotFound` that slipped through `work`), `execute!` re-raises the **original** exception, not a `Fault`. Match both in production rescue blocks if needed.

### 8. Retries share the same task instance

`context`, instance variables, and `task.errors` persist across retry attempts. If you re-add errors each time, clear them at the start of `work`, or the post-`work` check will still fail the task.

### 9. `task.result` isn't available inside callbacks

The `Result` is built *after* callbacks run. Inside callbacks, read `task.context` / `task.errors`; for finalized result data, subscribe to the `:task_executed` telemetry event.

### 10. Calling halt methods outside `work`

The signal `catch` only wraps input resolution, `work`, and output verification. `success!` / `skip!` / `fail!` / `throw!` invoked from `before_execution` / `before_validation` callbacks or middleware bubble past Runtime and never produce a `Result`. Use `errors.add` from validation callbacks instead, or move the logic into `work`.

## References

- [Inputs](references/inputs.md) — declarations, coercions, validators, naming, transforms, sources, nesting
- [Outputs](references/outputs.md) — declarations, verification, defaults, transforms
- [Workflows](references/workflows.md) — composition, strategies, halt behavior, rollback, nesting
- [Interruptions](references/interruptions.md) — signals, faults, errors, propagation strategies
- [Result](references/result.md) — states, statuses, handlers, pattern matching, chain analysis
- [Configuration](references/configuration.md) — global config, settings, retries, deprecation, registries, telemetry, Rails
- [Testing](references/testing.md) — RSpec patterns using the real public API
