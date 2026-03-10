---
name: cmdx
description: Build, debug, and optimize CMDx tasks and workflows in Ruby. Use when creating service/command objects with CMDx, composing business logic into workflows, handling task failures and interruptions, or working with CMDx attributes, callbacks, middleware, and configuration.
---

# CMDx Agent Skill

CMDx is a Ruby framework for composable command/service objects with built-in attribute validation, type coercion, error handling, and observability.

For full documentation, see the [docs/](docs/) directory or the [LLM reference](https://drexed.github.io/cmdx/llms-full.txt). Key doc pages are linked throughout this skill via progressive disclosure.

## Task Lifecycle (CERO)

Every task follows: **Compose → Execute → React → Observe**.

```
middlewares.call!(task) do
  before_validation → define & validate attributes → fail! if errors
  before_execution → result.executing! → task.work
  verify returns
rescue Fault → result.throw!(fault.result)
rescue StandardError → retry or result.fail!
ensure
  result.executed!
  on_complete / on_interrupted       # by state
  on_executed                        # if execution ran
  on_success / on_skipped / on_failed # by status
  on_good / on_bad                   # by status group
  log → rollback? → freeze → clear chain
end
```

## Minimal Task

```ruby
class Greet < CMDx::Task
  required :name, type: :string, presence: true

  def work
    context.greeting = "Hello, #{name}!"
  end
end

result = Greet.execute(name: "World")
result.success?          #=> true
result.context.greeting  #=> "Hello, World!"
```

## Full-Featured Task

```ruby
class ProcessPayment < CMDx::Task
  settings(
    retries: 3,
    retry_on: [Gateway::TimeoutError],
    retry_jitter: :exponential_backoff,
    rollback_on: ["failed"],
    tags: ["billing"]
  )

  register :middleware, CMDx::Middlewares::Timeout, seconds: 10
  register :middleware, CMDx::Middlewares::Runtime

  before_execution :find_order
  on_success :send_receipt
  on_failed :alert_support, if: -> { context.amount > 1000 }

  required :order_id, type: :integer
  required :amount, type: :big_decimal, numeric: { greater_than: 0 }
  optional :currency, type: :string, default: "USD", inclusion: { in: %w[USD EUR GBP] }
  optional :idempotency_key, type: :string, default: -> { SecureRandom.uuid }

  returns :charge_id, :receipt_url

  def work
    charge = Gateway.charge!(amount: amount, currency: currency, key: idempotency_key)
    context.charge_id = charge.id
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

  def alert_support
    SupportNotifier.high_value_failure(@order, result.reason)
  end
end
```

## Workflow Example

Workflows compose tasks into sequential or parallel execution groups.

```ruby
class OnboardCustomer < CMDx::Task
  include CMDx::Workflow

  task ValidateIdentity
  task CreateAccount, breakpoints: %w[failed]
  task SetupBilling, if: :billing_required?
  tasks SendWelcomeEmail, SendWelcomeSms, strategy: :parallel

  private

  def billing_required?
    context.plan != "free"
  end
end

result = OnboardCustomer.execute(email: "user@example.com", plan: "pro")
```

Workflows share a single context across all tasks. A failing task halts execution when its status matches the group's breakpoints (default: `["failed"]`).

For advanced patterns, see [references/workflows.md](references/workflows.md) and [docs/workflows.md](docs/workflows.md).

## Attributes

Declared with `required`, `optional`, or `attribute`:

```ruby
class Example < CMDx::Task
  required :email, type: :string, format: { with: URI::MailTo::EMAIL_REGEXP }
  optional :role, type: :string, default: "member", inclusion: { in: %w[admin member guest] }
  attribute :notes, required: false

  def work
    # Attributes accessible as methods: email, role, notes
    # These return coerced/validated values (see pitfall #2)
  end
end
```

### Pipeline

Each attribute flows through: **Source → Coerce → Transform → Validate**.

### Type coercion

Built-in types: `:array`, `:big_decimal`, `:boolean`, `:complex`, `:date`, `:datetime`, `:float`, `:hash`, `:integer`, `:rational`, `:string`, `:symbol`, `:time`.

```ruby
required :count, type: :integer           # single type
required :value, types: [Integer, Float]  # multiple types
```

### Validations

Built-in: `presence`, `absence`, `format`, `length`, `numeric`, `inclusion`, `exclusion`.

```ruby
required :age, type: :integer, numeric: { greater_than: 0, less_than: 150 }
required :code, type: :string, length: { is: 6 }, format: { with: /\A[A-Z0-9]+\z/ }
optional :tags, type: :array, length: { maximum: 10 }
```

### Naming

```ruby
attribute :template, prefix: true           # method: context_template
attribute :format, prefix: "report_"        # method: report_format
attribute :branch, suffix: true             # method: branch_context
attribute :scheduled_at, as: :when          # method: when
```

### Transforms

```ruby
attribute :email, transform: :strip
attribute :tags, transform: :compact_blank
attribute :score, type: :integer, transform: proc { |v| v.clamp(0, 100) }
```

For the complete attribute reference, see [references/attributes.md](references/attributes.md). Deep dives: [docs/attributes/definitions.md](docs/attributes/definitions.md), [docs/attributes/coercions.md](docs/attributes/coercions.md), [docs/attributes/validations.md](docs/attributes/validations.md).

## Interruptions

### skip! and fail!

```ruby
def work
  skip!("Already processed")                                          # halts
  skip!("Duplicate", halt: false)                                     # continues
  fail!("Not found", code: 404)                                       # halts
  fail!("Validation failed", halt: false, errors: validation_errors)  # continues
end
```

### throw!

Propagates another task's result upward:

```ruby
def work
  inner_result = InnerTask.execute(context)
  throw!(inner_result) if inner_result.failed?
end
```

### Faults

`execute` never raises — returns a `Result`. `execute!` raises `CMDx::FailFault` or `CMDx::SkipFault` when the status matches breakpoints.

```ruby
result = MyTask.execute(data: input)
result.success?

begin
  result = MyTask.execute!(data: input)
rescue CMDx::FailFault => e
  e.result         # the failed Result
  e.context        # the context (delegated from result)
  e.message        # failure reason string (set from result.reason)
  e.result.reason  # same reason via result
end
```

#### Fault matching

`for?` and `matches?` are class methods that return matcher classes for use in `rescue`:

```ruby
rescue CMDx::FailFault.for?(PaymentTask, BillingTask) => e
  # only catches FailFaults from PaymentTask or BillingTask
rescue CMDx::FailFault.matches? { |f| f.result.metadata[:critical] } => e
  # only catches FailFaults where the block returns true
end
```

## Result

```ruby
result = MyTask.execute(input: data)

# State: initialized, executing, complete, interrupted
result.state         #=> "complete"
result.complete?     #=> true
result.interrupted?  #=> false

# Status: success, skipped, failed
result.status        #=> "success"
result.success?      #=> true
result.good?         #=> true  (success OR skipped)
result.bad?          #=> false (skipped OR failed)

# Data
result.context       # shared Context object
result.reason        # skip/fail reason string
result.cause         # the Fault that caused interruption
result.metadata      # hash of extra data (errors, runtime, etc.)
result.chain         # Chain of results in execution

# Handlers
result.on(:success) { |r| redirect_to(dashboard_path) }
      .on(:failed)  { |r| render_error(r.reason) }
      .on(:skipped) { |r| log_skip(r.reason) }

# Pattern matching
case result
in ["complete", "success"] then handle_success
in ["interrupted", "failed"] then handle_failure
end
```

## Callbacks

Registered as class methods. Accept method names, procs, or blocks. Support `if:`/`unless:` conditions.

```ruby
class Example < CMDx::Task
  before_validation :normalize_input
  before_execution :load_dependencies
  on_success :notify_user, if: -> { context.notify? }
  on_failed :log_failure
  on_complete :cleanup
end
```

### Execution order

1. `before_validation` — before attribute validation
2. `before_execution` — after validation, before `work`
3. `on_complete` / `on_interrupted` — by state
4. `on_executed` — if execution ran
5. `on_success` / `on_skipped` / `on_failed` — by status
6. `on_good` / `on_bad` — by status group

## Middleware

Wraps the entire execution. Must yield.

```ruby
# Built-in
register :middleware, CMDx::Middlewares::Timeout, seconds: 5
register :middleware, CMDx::Middlewares::Runtime          # result.metadata[:runtime]
register :middleware, CMDx::Middlewares::Correlate, id: proc { SecureRandom.uuid }

# Custom
class AuditMiddleware
  def self.call(task, **options)
    AuditLog.start(task.class.name)
    yield(task)
  ensure
    AuditLog.finish(task.class.name, task.result.status)
  end
end

register :middleware, AuditMiddleware
```

## Configuration

### Global

```ruby
CMDx.configure do |config|
  config.task_breakpoints = "failed"
  config.workflow_breakpoints = ["skipped", "failed"]
  config.rollback_on = ["failed"]
  config.freeze_results = true
  config.backtrace = false
  config.logger = Logger.new($stdout)
  config.exception_handler = proc { |task, e| ErrorTracker.report(e) }
end
```

### Per-task

```ruby
class MyTask < CMDx::Task
  settings(
    retries: 3,
    retry_on: [Net::TimeoutError],
    retry_jitter: :exponential_backoff,
    rollback_on: ["failed"],
    task_breakpoints: ["failed"],
    tags: ["critical"],
    log_level: :info,
    log_formatter: CMDx::LogFormatters::Json.new,
    deprecate: :log
  )
end
```

For all options, see [references/configuration.md](references/configuration.md) and [docs/configuration.md](docs/configuration.md).

## Returns (Output Contract)

```ruby
class CreateUser < CMDx::Task
  returns :user, :token

  def work
    context.user = User.create!(params)
    context.token = generate_token(context.user)
  end
end
```

Missing returns cause the task to fail with validation errors.

## Context

A shared, hash-like object passed through tasks:

```ruby
context[:key]                    # read
context.key                      # read (method_missing)
context.key = value              # write
context.store(:key, value)       # write
context.merge!(hash)             # bulk write
context.fetch(:key, default)     # read with default
context.fetch_or_store(:key, v)  # read or write
context.key?(:key)               # existence check
context.dig(:a, :b, :c)         # nested read
context.delete!(:key)            # remove
```

## Retries

```ruby
settings retries: 3, retry_on: [Net::TimeoutError]
settings retries: 5, retry_jitter: :exponential_backoff
settings retries: 10, retry_jitter: ->(count) { [count * 0.5, 5.0].min }
```

Only retries when the rescued exception matches `retry_on`. Clears errors between attempts. See [docs/retries.md](docs/retries.md).

## Dry Run

```ruby
result = MyTask.execute(data: input, dry_run: true)
result.dry_run? #=> true
```

The `work` method still runs — implement dry-run guards inside `work` using `dry_run?` (delegated from task to chain).

## Common Pitfalls

### 1. Forgetting `def work`

Every task must define `work`. Without it, execution raises `CMDx::UndefinedMethodError`.

### 2. Using `context` vs attribute methods

```ruby
# Wrong: bypasses validation/coercion
def work
  context.email
end

# Right: declare attributes, use generated methods
required :email, type: :string
def work
  email
end
```

### 3. Not handling `throw!` in nested tasks

```ruby
# Wrong: inner failure is silently swallowed
def work
  InnerTask.execute(context)
end

# Right: propagate or check the result
def work
  inner = InnerTask.execute(context)
  throw!(inner) unless inner.success?
end
```

### 4. Mutating context after freeze

Results are frozen by default (`freeze_results: true`). Attempting to modify context after execution raises an error. Set `freeze_results: false` if post-execution mutation is needed.

### 5. Middleware that doesn't yield

A middleware that omits `yield` silently swallows execution. The result will be marked as failed with `metadata[:source] == :swallowed_middleware`.

### 6. Breakpoints confusion

- `task_breakpoints`: controls when `execute!` raises (default: `["failed"]`)
- `workflow_breakpoints`: controls when a workflow halts (default: `["failed"]`)
- Group breakpoints: `tasks TaskA, TaskB, breakpoints: %w[skipped failed]`
- Empty breakpoints `[]` means never halt

### 7. Missing returns

Declared `returns` are verified after `work`. If the context doesn't contain the declared keys, the task fails with validation errors.

### 8. Attribute ordering

Attributes are order-dependent. If one attribute references another as a source or condition, declare the referenced attribute first:

```ruby
# Correct
required :credentials, source: :database_config
attribute :connection_string, source: :credentials

# Wrong: connection_string references credentials before it exists
attribute :connection_string, source: :credentials
required :credentials, source: :database_config
```

### 9. Exception vs Fault

`StandardError` exceptions are caught by `execute` and converted to failed results. `execute!` re-raises them. `CMDx::TimeoutError` inherits from `Interrupt`, not `StandardError` — it's always raised.

## References

- [Attribute details](references/attributes.md) — coercions, validations, naming, transforms, nesting
- [Workflow patterns](references/workflows.md) — composition, breakpoints, parallel, conditions
- [Interruptions & faults](references/interruptions.md) — skip!/fail!/throw!, propagation strategies, fault matching, errors
- [Result API](references/result.md) — states, statuses, handlers, pattern matching, chain analysis
- [Configuration options](references/configuration.md) — global and per-task settings
- [Testing guide](references/testing.md) — RSpec matchers, setup, patterns

### Deep-dive docs

- Basics: [setup](docs/basics/setup.md), [execution](docs/basics/execution.md), [context](docs/basics/context.md), [chain](docs/basics/chain.md)
- Interruptions: [halt](docs/interruptions/halt.md), [faults](docs/interruptions/faults.md), [exceptions](docs/interruptions/exceptions.md)
- Outcomes: [result](docs/outcomes/result.md), [states](docs/outcomes/states.md), [statuses](docs/outcomes/statuses.md)
- Features: [callbacks](docs/callbacks.md), [middlewares](docs/middlewares.md), [workflows](docs/workflows.md), [retries](docs/retries.md), [logging](docs/logging.md)
- [Testing](docs/testing.md) | [Tips & tricks](docs/tips_and_tricks.md) | [Comparison](docs/comparison.md)
