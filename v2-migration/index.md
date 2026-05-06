# Upgrading from v1.x to v2.0

CMDx 2.0 is a full runtime rewrite. The public DSL — `required`, `optional`, callbacks, middlewares, `retry_on`, `settings`, `Workflow` / `task` — largely survives, but halt semantics, attribute/return declarations, middleware signatures, and most internal classes have changed.

Not a drop-in upgrade

Plan to touch every task class. Halt is now `throw`/`catch` (not `Result` mutation), attributes became inputs (`type:` → `coerce:`), returns became outputs, middleware takes one arg and `yield`s, and the built-in middleware trio (`Correlate`, `Runtime`, `Timeout`) is gone. The [Automated Migration Prompt](#automated-migration-prompt) below mechanizes most of the rewrite — paste it into your agent before hand-editing.

Benchmarks

Halts are ~2.5× faster, workflow failures ~3×, allocations down 50–80%. See [`benchmark/RESULTS.md`](https://github.com/drexed/cmdx/blob/main/benchmark/RESULTS.md).

______________________________________________________________________

## Before You Begin

1. **Check requirements.** Ruby 3.3+ (MRI, JRuby, or TruffleRuby). See [Getting Started](https://drexed.github.io/cmdx/getting_started/#requirements).
1. **Pin your current version.** `gem "cmdx", "~> 1.21"` in the `Gemfile` — a quick rollback path if the upgrade stalls.
1. **Baseline the suite.** Run `bundle exec rspec` on v1.x once and save the output; a green suite is your "before" snapshot.
1. **Skim the changelog.** The `[2.0.0]` section of [`CHANGELOG.md`](https://github.com/drexed/cmdx/blob/main/CHANGELOG.md) lists every breaking change by category.
1. **Read this page top-to-bottom.** Each section is a recipe you can apply independently.

______________________________________________________________________

## TL;DR Cheat Sheet

| Area                    | v1.x                                           | v2.0                                                                                                                 |
| ----------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Halt mechanism          | mutate `Result` state machine                  | `catch`/`throw` a frozen `Signal`                                                                                    |
| `Result` mutability     | mutable (`initialized → executing → complete`) | read-only; options frozen on construction                                                                            |
| Lifecycle owner         | `CMDx::Executor`                               | `CMDx::Runtime`                                                                                                      |
| Inputs                  | `attribute` / `attributes` with `type:`        | `input` / `inputs` with `coerce:`                                                                                    |
| Outputs                 | `returns :user, :token` (presence check only)  | `output :user, default: ..., if: ...` (every declared output is implicitly required; defaults + guards are optional) |
| Callbacks               | `on_executed`, `on_good`, `on_bad`             | drops `on_executed`; renames to `on_ok` / `on_ko`                                                                    |
| Middleware signature    | `call(task, options, &block)`                  | `call(task) { yield }`                                                                                               |
| Built-in middlewares    | `Correlate`, `Runtime`, `Timeout`              | removed — register your own                                                                                          |
| Lifecycle observability | middleware-based                               | `Telemetry` pub/sub with 5 events                                                                                    |
| Workflow parallelism    | none / 3rd-party                               | `tasks ..., strategy: :parallel, pool_size: N`                                                                       |
| Chain storage           | thread-local                                   | fiber-local (parallel-safe)                                                                                          |
| Breakpoints             | `task_breakpoints` / `workflow_breakpoints`    | removed — use `execute!` for strict mode                                                                             |
| Loader                  | Zeitwerk                                       | explicit `require_relative`                                                                                          |
| Pattern matching        | n/a                                            | `case result in [*, [:status, "success"], *]`                                                                        |
| `result.task`           | task **instance**                              | task **class**                                                                                                       |
| `result.chain`          | results `Array`                                | `Chain` object (`Enumerable`)                                                                                        |

______________________________________________________________________

## Upgrade Workflow

1. **Bump the gem.** `bundle update cmdx` and run the suite to surface breakage.
1. **Fix configuration.** Drop removed keys (see [Configuration](#configuration)). `rails generate cmdx:install` regenerates the v2 initializer as a reference.
1. **Fix tasks category-by-category.** Inputs → Outputs → Callbacks → Middlewares → Result consumers. The [Automated Migration Prompt](#automated-migration-prompt) mechanizes most of this.
1. **Audit result-handling code** for state-machine assumptions (`result.executing?`, `result.metadata[:x] = ...`, `result.cid`, `result.good?` / `bad?`) and any breakpoint / strict-mode configuration.
1. **Move observability** (correlation IDs, runtime metrics, timeouts) to [Telemetry](#telemetry) subscribers or hand-rolled middlewares.
1. **Re-run the suite.** When green, delete dead helpers that papered over v1's rough edges (manual rollbacks, `dry_run:` flags, `SKIP_CMDX_FREEZING` toggles).
1. **Validate.** Run the grep list in [Validating the Migration](#validating-the-migration) to catch stragglers.

______________________________________________________________________

## Configuration

The `CMDx::Configuration` surface shrank. Breakpoints, rollback config, freezing, and exception handlers are gone; what remains is registries plus logging/locale.

### Removed Keys

| Removed                                                            | Replacement |
| ------------------------------------------------------------------ | ----------- |
| `task_breakpoints`, `workflow_breakpoints`                         | Removed.    |
| `rollback_on`                                                      | Removed.    |
| `dump_context`, `freeze_results`, `backtrace`, `exception_handler` | Removed.    |
| `SKIP_CMDX_FREEZING` env var                                       | Removed.    |

### v2 Surface

```ruby
CMDx.configure do |config|
  config.middlewares       # CMDx::Middlewares
  config.callbacks         # CMDx::Callbacks
  config.coercions         # CMDx::Coercions
  config.validators        # CMDx::Validators
  config.executors         # CMDx::Executors
  config.mergers           # CMDx::Mergers
  config.retriers          # CMDx::Retriers
  config.deprecators       # CMDx::Deprecators
  config.telemetry         # CMDx::Telemetry
  config.correlation_id    # nil or callable resolving an external request id
  config.strict_context    # false (raise on unknown `context` reads when true)
  config.default_locale    # "en"
  config.backtrace_cleaner # ->(bt) { ... } or nil
  config.logger            # Logger instance
  config.log_level         # nil (optional override; defaults come from `logger.level`)
  config.log_formatter     # nil (optional override; defaults come from `logger.formatter`)
  config.log_exclusions    # [] (Result#to_h keys stripped from the lifecycle log entry)
end
```

See [Configuration](https://drexed.github.io/cmdx/configuration/index.md) for the full surface.

______________________________________________________________________

## Task Definition

`def work` is unchanged. v2 raises `ImplementationError` (was `UndefinedMethodError`) if you don't override it.

### Execution Entry Points

```ruby
MyTask.execute(name: "x")       # unchanged
MyTask.execute!(name: "x")      # unchanged
MyTask.call / .call!            # still aliases of execute / execute!

task = MyTask.new(name: "x")
task.execute                    # unchanged
task.execute(strict: true)      # unchanged
task.call / .call(strict: true) # still aliases of execute / execute!
```

`MyTask.new(ctx).execute` runs an already-built task instance through `Runtime`. The class-level `MyTask.execute` / `MyTask.execute!` simply forward to it. `Runtime.execute(task)` is still available for callers that need to drive the lifecycle directly without going through `Task`.

### Removed Instance Accessors

Read task-level data off the returned `Result` instead.

| v1                                    | v2                                                                    |
| ------------------------------------- | --------------------------------------------------------------------- |
| `MyTask.execute(...).task` → instance | `result.task` → **class** (see [Result Consumers](#result-consumers)) |
| `task.id`                             | `result.tid`                                                          |
| `task.result`                         | `execute` returns the `Result` directly                               |
| `task.chain`                          | `result.chain` (a `Chain`, not an Array)                              |
| `task.dry_run?`                       | removed — `dry_run` is gone                                           |

`task.context`, `task.errors`, and `task.logger` still exist on the instance during `work`.

______________________________________________________________________

## Halts

`success!` / `skip!` / `fail!` / `throw!` are private instance methods on `Task` that `throw(Signal::TAG, signal)`. Runtime's `catch` intercepts the signal and constructs the result once at the end.

Breaking changes:

- `result.fail!` / `result.skip!` are gone — halts live on `Task`, not delegated through `Result`.
- `success!` is new — halt `work` early while staying successful.
- Only `fail!` and `throw!` capture `caller_locations(1)` as the signal backtrace; `success!` and `skip!` do not. `Fault#backtrace` points at your call site, cleaned through `Settings#backtrace_cleaner` when present.
- `throw!(other_result)` is a no-op when `other_result` didn't fail (same as v1; now implemented as a `Signal.echoed` throw).
- Calling any halt method on a frozen task raises `FrozenError`.

See [Interruptions - Signals](https://drexed.github.io/cmdx/interruptions/signals/index.md) for the full semantics.

______________________________________________________________________

## Inputs (was Attributes)

Rename `attribute` / `attributes` to `input` / `inputs`, and `type:` to `coerce:`. `required` / `optional` aliases are unchanged.

| v1                                                | v2                                                         |
| ------------------------------------------------- | ---------------------------------------------------------- |
| `attribute :email, type: :string, required: true` | `input :email, coerce: :string, required: true`            |
| `attributes :name, :role, type: :string`          | `inputs :name, :role, coerce: :string`                     |
| `type: :integer`                                  | `coerce: :integer`                                         |
| `type: [:integer, :float]`                        | `coerce: %i[integer float]`                                |
| `type: { date: { strptime: "..." } }`             | `coerce: { date: { strptime: "..." } }`                    |
| `remove_attribute :flag`                          | `deregister :input, :flag`                                 |
| `MyTask.attributes_schema`                        | `MyTask.inputs_schema` (plus `MyTask.outputs_schema`, new) |

`source:` (`:context`, method name, Proc, lambda) and nested-input blocks are unchanged.

### Removed

- `Attribute`, `AttributeRegistry`, `AttributeValue`, `Resolver`, `Identifier` classes

### Bridge

Want to keep using `attribute` and `attributes`?

```text
class ApplicationTask
  class << self
    alias attribute input
    alias attributes inputs
  end
end
```

See [Inputs - Definitions](https://drexed.github.io/cmdx/inputs/definitions/index.md).

______________________________________________________________________

## Outputs (was Returns)

`returns` was a presence check. `output` keeps the same implicit-required semantics and adds optional `:default` and `:if`/`:unless` gates. Outputs are intentionally minimal — for coercion, transformation, or validation use [Inputs](https://drexed.github.io/cmdx/inputs/definitions/index.md) (or compute in `work`).

```ruby
# v1
returns :user, :token

# v2
output :user
output :token, default: -> { JwtService.encode(user_id: context.user.id) }
```

Outputs run **after** `work` returns successfully (skipped if the task halted). Every declared output is implicitly required: a missing key adds `outputs.missing` to `task.errors`, which Runtime converts into a failed signal. `:default` satisfies the check when it produces a non-nil value.

### Removed

| Removed                           | Replacement                 |
| --------------------------------- | --------------------------- |
| `returns :name`                   | `output :name`              |
| `remove_returns :name`            | `deregister :output, :name` |
| `cmdx.returns.missing` locale key | `cmdx.outputs.missing`      |

### Bridge

Want to keep using `returns`?

```text
class ApplicationTask
  class << self
    alias returns outputs
  end
end
```

See [Outputs](https://drexed.github.io/cmdx/outputs/index.md) for the full surface.

______________________________________________________________________

## Callbacks

### Event Renames

| v1                                                                                                                | v2        |
| ----------------------------------------------------------------------------------------------------------------- | --------- |
| `before_validation`, `before_execution`, `on_complete`, `on_interrupted`, `on_success`, `on_skipped`, `on_failed` | unchanged |
| `on_executed`                                                                                                     | removed   |
| `on_good`                                                                                                         | `on_ok`   |
| `on_bad`                                                                                                          | `on_ko`   |

### Registration

Every event has an auto-defined DSL method; `register :callback, ...` still works.

```ruby
class MyTask < CMDx::Task
  on_failed  :alert_team
  on_success ->(task) { Stats.bump(:ok) }
  on_success { Stats.bump(:ok) }                  # block form
  register :callback, :on_failed, :alert_team     # still supported
end
```

Handlers may be a `Symbol` (dispatched via `task.send`), a `Proc` (`instance_exec`'d with the task), or any `#call`-able (invoked with the task). Unknown events and unsupported handlers raise `ArgumentError`.

### Deregistration

```ruby
deregister :callback, :on_failed                 # drops every callback for :on_failed
deregister :callback, :on_failed, :alert_team    # drops only this entry (matched by ==)
```

See [Callbacks](https://drexed.github.io/cmdx/callbacks/index.md) for Proc-identity caveats and conditional gates.

______________________________________________________________________

## Middlewares

### New Signature

```ruby
# v1
class Timing
  def call(task, options, &block)
    started = monotonic
    result  = block.call
    result.metadata[:ms] = elapsed
    result
  end
end

# v2
class Timing
  def call(task)
    started = monotonic
    yield
  ensure
    task.metadata[:ms] = elapsed
  end
end
```

Procs and lambdas must capture the next link explicitly — `yield` in a lambda targets the enclosing method:

```ruby
->(task, &next_link) { next_link.call }
proc { |task, &next_link| next_link.call }
```

Differences:

- **No `options` parameter.** Carry config on the middleware instance.
- **No return-value contract.** Middlewares wrap; Runtime builds the result after the chain unwinds.
- **Must yield.** Skipping `yield` raises `CMDx::MiddlewareError`. The task body never runs, and the error propagates out of both `execute` and `execute!`.
- **Result data isn't visible inside the chain.** Read `task.context` / `task.errors` while wrapping; subscribe to Telemetry's `:task_executed` when you need the finalized `Result`.

### Registration

The registry no longer auto-instantiates classes or forwards `**options`. Pass a `#call`-able (class instance, proc, lambda) or a block.

| v1                                                                 | v2                                                                     |
| ------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `register :middleware, TelemetryMiddleware`                        | `register :middleware, TelemetryMiddleware.new`                        |
| `register :middleware, MonitorMiddleware, service_key: ENV["KEY"]` | `register :middleware, MonitorMiddleware.new(service_key: ENV["KEY"])` |
| `register :middleware, AuditMiddleware, at: 0`                     | `register :middleware, AuditMiddleware.new, at: 0`                     |

### Built-ins Removed

| Removed                        | Replacement                                                                                                                                                                                                                          |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `CMDx::Middlewares::Correlate` | Built-in: configure `CMDx.configuration.correlation_id = -> { ... }` to surface `xid` on `Chain`/`Result`/`Telemetry::Event` (see [Configuration - Correlation ID](https://drexed.github.io/cmdx/configuration/#correlation-id-xid)) |
| `CMDx::Middlewares::Runtime`   | `result.duration` is built in; `:task_executed` Telemetry for richer payloads                                                                                                                                                        |
| `CMDx::Middlewares::Timeout`   | wrap `yield` in your own `Timeout.timeout(n)` middleware                                                                                                                                                                             |

### Deregistration

Middleware identity is by-reference — deregister with the exact instance you registered, or by index:

```ruby
deregister :middleware, audit_instance
deregister :middleware, at: 0
```

See [Middlewares](https://drexed.github.io/cmdx/middlewares/index.md) for the full surface.

______________________________________________________________________

## Settings

`Settings` is a frozen value object. Per-task overrides cover logger, log formatter, log level, log exclusions, backtrace cleaner, tags, and strict context — nothing else. Registries live on the `Task` class itself.

```ruby
# v1
settings logger:           MyLogger.new,
         tags:             %i[critical],
         task_breakpoints: %w[failed], # gone in v2
         freeze_results:   false       # gone in v2

# v2
settings logger:            MyLogger.new,
         log_formatter:     CMDx::LogFormatters::JSON.new,
         log_level:         Logger::DEBUG,
         log_exclusions:    %i[context metadata],
         backtrace_cleaner: ->(bt) { bt.reject { |l| l.include?("gems/") } },
         tags:              %i[critical]
```

`Settings#build(opts)` returns a new instance and does a flat `Hash#merge` — a subclass that overrides `tags:` **replaces** (not concatenates) the parent's. Every getter falls back to `CMDx.configuration` when the key is absent.

`MyTask.middlewares`, `.callbacks`, `.coercions`, `.validators`, `.telemetry`, `.inputs`, `.outputs` are class-level accessors that lazy-clone from the superclass (or global config) on first read. Subclasses extend — they never replace.

______________________________________________________________________

## Result Consumers

### Mutability

```ruby
result = MyTask.execute(...)

# v1: result.metadata[:foo] = :bar    # allowed
# v2: Result exposes no mutating API.
result.task.frozen?     #=> true
result.errors.frozen?   #=> true
result.context.frozen?  #=> true (root only)
CMDx::Chain.current     #=> nil (cleared on root teardown)
```

Note

User-supplied `metadata:` hashes (passed to `success!` / `skip!` / `fail!`) are **not** deep-frozen — freeze them yourself before throwing if you need that guarantee.

### Predicate Renames

| v1                                                                                                | v2                                                                                                    |
| ------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `Result::STATES` (4 states)                                                                       | `Signal::STATES` (2 states: `"complete"`, `"interrupted"`)                                            |
| `result.initialized?`, `result.executing?`, `result.executed?`                                    | **removed** — a `Result` only exists post-finalization                                                |
| `result.complete?`, `result.interrupted?`, `result.success?`, `result.skipped?`, `result.failed?` | unchanged                                                                                             |
| `result.good?`                                                                                    | `result.ok?`                                                                                          |
| `result.bad?`                                                                                     | `result.ko?`                                                                                          |
| `result.chain_id`                                                                                 | `result.cid`                                                                                          |
| `result.task` (instance)                                                                          | `result.task` (**class**)                                                                             |
| `result.chain` (Array)                                                                            | `result.chain` (`Chain`, Enumerable)                                                                  |
| `result.threw_failure?`                                                                           | `result.thrown_failure?` (semantics flipped: true only when this result re-threw an upstream failure) |

### New Surface

```ruby
result.on(:success) { |r| deliver(r.context) }    # predicate dispatch
      .on(:failed)  { |r| alert(r.reason) }
# Accepted keys: :complete :interrupted :success :skipped :failed :ok :ko

case result                                          # pattern matching
in [*, [:status, "success"], *]                      then ok!
in [*, [:status, "failed"], *, [:reason, reason], *] then alert(reason)
in { task:, status: "failed", cause: }               then ...
end

result.tid             # uuid_v7
result.chain           # Chain (Enumerable)
result.cid             # chain's uuid_v7
result.index           # position in chain
result.root?           # true when this result is the chain's root
result.duration        # milliseconds (Float)
result.retries         # integer
result.retried?        # bool
result.strict?         # produced via execute!
result.deprecated?     # task class marked deprecated
result.rolled_back?    # rollback ran
result.tags            # settings.tags
```

### Failure References

```ruby
result.threw_failure   # origin || self (nearest upstream failed, or self when originator)
result.thrown_failure? # true only when this result re-threw an upstream failure
result.caused_failure  # walks `origin` to the root-cause leaf
result.caused_failure? # true when this result originated the failure
```

`Result#to_h` no longer recursively serializes failure chains. `origin`, `threw_failure`, and `caused_failure` render as `{ task: Class, tid: uuid }`, and `to_s` formats them as `<TaskClass uuid>`.

See [Outcomes - Result](https://drexed.github.io/cmdx/outcomes/result/index.md) for the full surface.

______________________________________________________________________

## Workflows

### Parallel Groups (NEW)

```ruby
class FanOutWorkflow < CMDx::Task
  include CMDx::Workflow

  task  LoadInvoice
  tasks ChargeCard, EmailReceipt, strategy:  :parallel, pool_size: 4
  task  FinalizeOrder
end
```

- Each parallel worker `deep_dup`s the workflow context, runs its task, then merges its successful child context back into the workflow (on the parent thread, after all workers join).
- All workers share the parent's fiber-local `Chain` — each worker sets `Fiber[Chain::STORAGE_KEY]` on thread entry, and each result is pushed under a `Mutex`.
- By default (`continue_on_failure: false`), pending workers are drained as soon as any sibling fails (in-flight tasks still finish, successful contexts still merge), and the first failure **by declaration index** is propagated. With `continue_on_failure: true`, every worker runs to completion and all failures are aggregated into the workflow's `errors` (keyed `:"TaskClass.<input>"` for input/validation errors and `:"TaskClass.<status>"` for bare `fail!` reasons); the first failure **by declaration index** is still the one propagated via `throw!`.
- Additional knobs: `:executor` (`:threads` default, `:fibers`, or a callable), `:merger` (`:last_write_wins` default, `:deep_merge`, `:no_merge`, or a callable), and `:continue_on_failure`. See [Workflows - Parallel Execution](https://drexed.github.io/cmdx/workflows/#parallel-execution).

### Behavioral Changes

- Defining `#work` on a workflow raises `ImplementationError` — the check fires only for methods defined **on the workflow subclass itself**, so `Workflow#work` (the delegator) is fine.
- `:if` / `:unless` gate the entire group.
- `workflow_breakpoints` is gone — failure always halts the pipeline. To keep going on a skip, branch explicitly in a wrapping task or middleware.

See [Workflows](https://drexed.github.io/cmdx/workflows/index.md).

______________________________________________________________________

## Chain

```ruby
# v1
Thread.current[:cmdx_chain]
chain.dry_run? # gone in v2

# v2
Fiber[:cmdx_chain]
Chain.current
Chain.current=
Chain.clear
```

`Chain` is fiber-local so parallel workers each see the same underlying chain. `push` and `unshift` are `Mutex`-synchronized. Runtime `unshift`s the root result and `push`es children, so `chain[0]` (and `chain.root`) is always the outermost task regardless of finalization order.

New in v2:

- `Chain#root`, `Chain#state`, `Chain#status` — delegate to the root result (`nil` when absent).
- `Chain#last` — most recently appended result.
- `Chain#freeze` — Runtime freezes the chain (and its results array) on root teardown; later mutations raise `FrozenError`.
- `Chain` `include`s `Enumerable`, so `chain.map(&:status)`, `chain.find(&:failed?)`, `chain.first(3)`, `chain.to_a` all work.

Important

`Result#chain` now returns the `Chain` itself, not its results array. Call `chain.id` for the uuid, `chain.to_a` for a plain array, or iterate directly via Enumerable.

______________________________________________________________________

## Faults & Exceptions

### Hierarchy

```text
CMDx::Error = CMDx::Exception    (StandardError)
├── CMDx::Fault
├── CMDx::DeprecationError
├── CMDx::DefinitionError        (NEW — conflicting input accessor, or empty workflow task group)
├── CMDx::ImplementationError    (NEW — Task#work unoverridden, or Workflow#work defined)
└── CMDx::MiddlewareError        (NEW — middleware didn't yield)
```

`CMDx::UndefinedMethodError` is gone. Exception classes are now declared inline in `lib/cmdx.rb` (was `lib/cmdx/exception.rb`).

### Matcher API

```ruby
rescue Fault.for?(ProcessOrder, ChargeCard) => fault
  Alert.for(fault.task, fault.message)
end

rescue Fault.reason?("api rate limit") => fault
  RetryQueue.push(fault)
end

rescue Fault.matches? { |f| f.result.metadata[:retryable] } => fault
  RetryQueue.push(fault)
end
```

### Construction

`fault.task`, `fault.context`, `fault.chain`, and `fault.result` are all exposed.

Note

`SkipFault` / `FailFault` (v1) are gone. There's just `Fault` — distinguish via `fault.result.skipped?` / `fault.result.failed?`.

______________________________________________________________________

## Errors

`Errors` `include`s `Enumerable`, iterating `[key, Set<String>]` pairs (not `Array`).

New in v2:

```ruby
errors.added?(:email, "is invalid")
errors.full_messages      #=> { email: ["email is invalid"] }
errors.to_hash(true)      # full_messages
errors.count              # total messages across all keys
errors.each_key { ... }
errors.each_value { ... }
```

`errors[:email]` returns `Array<String>` (deduped via the backing Set).

______________________________________________________________________

## Context

```ruby
context.merge(other)               # accepts Context, Hash, or anything to_h-able
context.retrieve(:foo) { compute } # fetch-or-store
context.delete(:foo)
context.clear
context.deep_dup
context.map { |k, v| ... }         # Enumerable
```

Dynamic accessors (`context.foo`, `context.foo = 1`) are unchanged. An accessor predicted has been added, eg: `context.foo?`

______________________________________________________________________

## Retries

Shape unchanged; implementation is now a value object that accumulates across inheritance.

```ruby
class FlakyTask < CMDx::Task
  retry_on Net::ReadTimeout, ConnectionPool::TimeoutError, limit: 4, delay: 0.5, max_delay: 5.0, jitter: :exponential
end

class ChildTask < FlakyTask
  retry_on Errno::ECONNRESET
end
```

See [Retries](https://drexed.github.io/cmdx/retries/index.md) for full options.

______________________________________________________________________

## Deprecation

v1's `Deprecator` class is replaced by a class-level `deprecation` DSL.

```ruby
class LegacyImporter < CMDx::Task
  deprecation :warn # :log, :warn, :error, Symbol, Proc, or any #call-able
  # deprecation :error, if: -> { Rails.env.production? }
  # deprecation ->(task) { Sentry.capture_message("deprecated task run: #{task.class}") }

  def work
    # ...
  end
end
```

Runtime invokes the deprecation right before the task body runs, sets `result.deprecated?` to `true`, and emits `:task_deprecated`. With `:error`, it raises `DeprecationError` and the task never runs. See [Deprecation](https://drexed.github.io/cmdx/deprecation/index.md).

______________________________________________________________________

## Rollback

`Task#rollback` is now a first-class lifecycle hook. When `work` fails, Runtime calls `rollback` if defined (after `work`, before result finalization), sets `result.rolled_back?` to `true`, and emits `:task_rolled_back`.

```ruby
class ChargeCard < CMDx::Task
  required :order_id, :amount

  def work
    context.charge = Stripe::Charge.create(amount:, source: order.source)
  end

  def rollback
    Stripe::Refund.create(charge: context.charge.id) if context.charge
  end
end
```

______________________________________________________________________

## Telemetry

v1's pattern for observing the runtime was to write a middleware. v2 ships a dedicated pub/sub with five events that fire **only when subscribers exist** (zero cost otherwise).

```ruby
CMDx.configure do |config|
  config.telemetry.subscribe(:task_executed) do |event|
    StatsD.timing("cmdx.#{event.task}", event.payload[:result].duration)
  end

  config.telemetry.subscribe(:task_retried) do |event|
    Rails.logger.warn("retry #{event.payload[:attempt]} for #{event.task}")
  end
end
```

| Event               | Payload                |
| ------------------- | ---------------------- |
| `:task_started`     | empty                  |
| `:task_deprecated`  | empty                  |
| `:task_retried`     | `{ attempt: Integer }` |
| `:task_rolled_back` | empty                  |
| `:task_executed`    | `{ result: Result }`   |

Every event carries a `Telemetry::Event` with `cid`, `root`, `type`, `task`, `tid`, `name`, `payload`, `timestamp`. Subscribe per-task via `MyTask.telemetry.subscribe(...)`. See [Configuration - Telemetry](https://drexed.github.io/cmdx/configuration/#telemetry).

______________________________________________________________________

## Locale & I18n

CMDx now ships `CMDx::I18nProxy`, which delegates to the `i18n` gem when loaded and falls back to bundled YAML otherwise. Default locale is `en`; override with `config.default_locale`.

### Key Renames

| v1                                                                                | v2                                          |
| --------------------------------------------------------------------------------- | ------------------------------------------- |
| `cmdx.attributes.required` ("must be accessible via the %{method} source method") | `cmdx.attributes.required` ("is required")  |
| `cmdx.attributes.undefined`                                                       | removed                                     |
| `cmdx.coercions.unknown`                                                          | removed                                     |
| `cmdx.faults.invalid`                                                             | removed                                     |
| `cmdx.faults.unspecified`                                                         | `cmdx.reasons.unspecified`                  |
| `cmdx.returns.missing`                                                            | `cmdx.outputs.missing`                      |
| —                                                                                 | `cmdx.validators.length.nil_value` (added)  |
| —                                                                                 | `cmdx.validators.numeric.nil_value` (added) |

### YAML Diff

```yaml
# Before (v1)
en:
  cmdx:
    attributes:
      required: "must be accessible via the %{method} source method"
      undefined: "..."
    coercions:
      unknown: "..."
    faults:
      invalid: "..."
      unspecified: "Unspecified"
    returns:
      missing: "must be set in the context"

# After (v2)
en:
  cmdx:
    attributes:
      required: "is required"
    reasons:
      unspecified: "Unspecified"
    outputs:
      missing: "must be set in the context"
    validators:
      length:
        nil_value: "must have a length"
      numeric:
        nil_value: "must be numeric"
```

Note

All 86+ internalization files have been moved to the [`cmdx-i18n`](https://github.com/drexed/cmdx-i18n) gem.

See [Internationalization](https://drexed.github.io/cmdx/internationalization/index.md).

______________________________________________________________________

## Generators

`cmdx:install`, `cmdx:task`, and `cmdx:workflow` emit the v2 template shape:

```ruby
class MyTask < ApplicationTask
  def work
    # Your logic here...
  end
end
```

Regenerate `cmdx:install` as a reference when migrating an initializer — it documents the v2 middleware / callback / telemetry / coercion / validator registration shapes.

______________________________________________________________________

## Removed Modules & Classes

| Removed                                                             | Replacement                                                                                                                      |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `CMDx::Executor`                                                    | `CMDx::Runtime`                                                                                                                  |
| `CMDx::Attribute` / `AttributeRegistry` / `AttributeValue`          | `CMDx::Input` + `CMDx::Inputs`                                                                                                   |
| `CMDx::Resolver`                                                    | input resolution on `Input#resolve`                                                                                              |
| `CMDx::Identifier`                                                  | `SecureRandom.uuid_v7`                                                                                                           |
| `CMDx::Locale`                                                      | `CMDx::I18nProxy`                                                                                                                |
| `CMDx::Deprecator`                                                  | declarative `Task.deprecation`                                                                                                   |
| `CMDx::Parallelizer`                                                | `CMDx::Pipeline#run_parallel` (`strategy: :parallel`)                                                                            |
| `CMDx::CallbackRegistry`                                            | `CMDx::Callbacks`                                                                                                                |
| `CMDx::MiddlewareRegistry`                                          | `CMDx::Middlewares`                                                                                                              |
| `CMDx::CoercionRegistry`                                            | `CMDx::Coercions`                                                                                                                |
| `CMDx::ValidatorRegistry`                                           | `CMDx::Validators`                                                                                                               |
| `CMDx::Utils::Call` / `Condition` / `Format` / `Normalize` / `Wrap` | `CMDx::Util` (conditional helpers only); `Array(x)` instead of `Wrap.array(x)`                                                   |
| `CMDx::Middlewares::Correlate` / `Runtime` / `Timeout`              | see [Built-ins Removed](#built-ins-removed)                                                                                      |
| `CMDx::UndefinedMethodError`                                        | `CMDx::ImplementationError`                                                                                                      |
| `CMDx::SkipFault` / `FailFault`                                     | `Fault` + `fault.result.skipped?` / `failed?`                                                                                    |
| Zeitwerk autoloading                                                | explicit `require_relative` in `lib/cmdx.rb` — gem no longer requires `zeitwerk`, `forwardable`, `pathname`, `set`, or `timeout` |
| `CMDx.gem_path` and the module-method surface                       | gone                                                                                                                             |

______________________________________________________________________

## Validating the Migration

Before you call it done:

**1. Run the suite.** `bundle exec rspec` must be green. For Rails projects, reset the global config between examples so registry caching on `Task` doesn't leak across tests:

```ruby
RSpec.configure do |c|
  c.before(:each) { CMDx.reset_configuration! }
end
```

**2. Grep for v1 symbols.** Any hit indicates missed migration:

```bash
rg --hidden \
  'task_breakpoints|workflow_breakpoints|rollback_on|dump_context|freeze_results|SKIP_CMDX_FREEZING|\.good\?|\.bad\?|cid[^=]|threw_failure\?|dry_run|attributes_schema|remove_attribute|remove_return|on_executed|on_good|on_bad|cmdx\.returns\.missing|cmdx\.faults\.(invalid|unspecified)|CMDx::Executor|CMDx::Middlewares::(Correlate|Runtime|Timeout)|CMDx::(SkipFault|FailFault|UndefinedMethodError)|register\s+:attribute|attribute\s+:'
```

**3. Check one log line.** A successful task logs a v2-shaped record with `cid`, `index`, `root`, `type`, `task`, `id`, `state`, `status`, `duration`:

```text
cmdx: cid="0190..." index=0 root=true type="Task" task=MyTask tid="0190..." state="complete" status="success" reason=nil metadata={} duration=12.34 ...
```

If you see `initialized` or `executing` in the output, something is serializing a v1 result.

______________________________________________________________________

## Troubleshooting

| Symptom                                                                       | Fix                                                                                                                     |
| ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `NoMethodError: undefined method 'good?' for Result`                          | `result.good?` → `result.ok?`, `result.bad?` → `result.ko?`                                                             |
| `NoMethodError: undefined method 'chain_id'`                                  | `result.chain_id` → `result.cid`                                                                                        |
| `NoMethodError: undefined method 'executed?' / 'executing?' / 'initialized?'` | Predicates removed; use `result.complete? \|\| result.interrupted?`                                                     |
| `CMDx::MiddlewareError: middleware did not yield the next_link`               | A middleware's `rescue` / `ensure` / early-return path skipped `yield`. Yield on every code path.                       |
| `CMDx::ImplementationError: cannot define Workflow#work`                      | A workflow subclass defined `#work`. Delete it and move the body into `task` / `tasks` declarations.                    |
| `FrozenError: cannot throw signals`                                           | `skip!` / `fail!` / `throw!` called on a frozen task (post-execution). Restructure to halt inside `work`.               |
| `Translation missing: cmdx.returns.missing`                                   | Rename locale key to `cmdx.outputs.missing`. Same for `cmdx.faults.unspecified` → `cmdx.reasons.unspecified`.           |
| `ArgumentError: middleware must respond to #call`                             | A middleware class was registered instead of an instance. Pass `MyMiddleware.new(...)`.                                 |
| `undefined method 'metadata=' for Result`                                     | `result.metadata[:x] = ...` writes aren't allowed. Set `task.context.x` **before** the halt instead.                    |
| `Fault#task` is a class, not an instance                                      | v2 behavior — `fault.result.task` is the class. Read instance-scoped data off `fault.context` / `fault.result.context`. |

______________________________________________________________________

## Rollback Plan

If the upgrade stalls:

1. `git revert` the migration branch.
1. Pin the gem: `gem "cmdx", "~> 1.21"`.
1. Restore any helpers you deleted (manual rollback dispatchers, breakpoint config, `dry_run` branches).

A handful of patterns are hard to shim under v1 once you've rewritten them — keep them in git history rather than trying to forward-port:

- Read-only `Result` access patterns (v1 `Result` is mutable, so nothing breaks if you leave guards in).
- `success!` calls (no v1 equivalent — replace with `return` or custom metadata).
- Parallel workflow groups (v1 has no first-class parallel strategy — fall back to running groups sequentially).
- Telemetry subscribers (wrap as v1 middlewares calling the same sinks).

______________________________________________________________________

## Automated Migration Prompt

Paste the block below into your agent (Cursor, Claude Code, etc.) with your project open. It's written to be idempotent — running it twice won't double-rewrite already-migrated code.

````markdown
You are upgrading a Ruby project from CMDx v1.x to v2.0.

Context:
- Project root: the current working directory.
- Source of truth: `docs/v2-migration.md` in the cmdx gem. When a v2 code
  example conflicts with older documentation, the migration doc wins.
- Ruby: MRI 3.3+ (or compatible JRuby/TruffleRuby).
- Scope: every file under `app/`, `lib/`, `spec/`, `test/`,
  `config/initializers/`, and any `*.rb` under the project root — unless an
  `.migrationignore` file exists, in which case respect it.

Idempotency rule:
- For every rewrite rule below, check whether the target code already matches
  the v2 shape. If it does, skip silently. Never re-apply a rule to code that
  already satisfies it.

Work in passes. After each pass, run `bundle exec rspec` (or the project's
equivalent) and fix failures before continuing. If a failure can't be resolved
by the rules here, stop and surface the file:line so a human can resolve it.

---

## Pass 1 — Inputs (lowest risk)

- Rename every `attribute` / `attributes` declaration to `input` / `inputs`.
  `required` / `optional` are unchanged.
- Rename every `type:` option to `coerce:`. Preserve array forms:
  `type: [:integer, :float]` → `coerce: %i[integer float]`.
- Replace `remove_attribute :name` with `deregister :input, :name`.
- Replace `MyTask.attributes_schema` with `MyTask.inputs_schema`.
- Replace `register :attribute, ...` with `required :name, ...` /
  `optional :name, ...` / `register :input, :name, ...`.

## Pass 2 — Outputs

- Replace `returns :a, :b` with one `output :a` / `output :b` per key.
  Every declared output is implicitly required — drop any leftover
  `required: true` option.
- Replace `remove_returns :name` with `deregister :output, :name`.
- Outputs only support `:default`, `:if`/`:unless`, and `:description`.
  Move any coercion / transformation / validation onto inputs or compute
  the value in `work` before assigning to context.

## Pass 3 — Locale files

- In every custom YAML under `config/locales/` (or wherever locales live):
  - `cmdx.returns.missing` → `cmdx.outputs.missing`.
  - `cmdx.faults.unspecified` → `cmdx.reasons.unspecified`.
  - Delete `cmdx.attributes.undefined`, `cmdx.coercions.unknown`,
    `cmdx.faults.invalid`.
  - If you override `cmdx.attributes.required`, update the string — v1's
    default was "must be accessible via the %{method} source method"; v2's
    default is "is required". Keep your custom override if it still reads
    naturally for the new context.

## Pass 4 — Callbacks

- Delete every `on_executed` callback; if the user was relying on it, replace
  with a pair of `on_complete` + `on_interrupted` callbacks (or `on_ok` /
  `on_ko`).
- Rename `on_good` → `on_ok`, `on_bad` → `on_ko`.

## Pass 5 — Result consumers

- `result.good?` → `result.ok?`; `result.bad?` → `result.ko?`.
- `result.chain_id` → `result.cid`.
- `result.threw_failure?` → `result.thrown_failure?` (semantics flipped —
  v2 is true ONLY when this result re-threw an upstream failure).
- Delete any `result.initialized?`, `result.executing?`, or
  `result.executed?` calls. For "did this task finish running", use
  `result.complete? || result.interrupted?`.
- Delete writes to `result.metadata[...] = ...` — `Result` is read-only.
  Move the data onto `task.context` BEFORE the halt.
- `result.task` now returns the task CLASS (v1 returned the instance). Code
  that called `result.task.id`, `result.task.context`, etc. needs
  `result.tid`, `result.context`, and so on.
- `result.chain` now returns the `Chain` object (Enumerable), not an Array.
  `result.chain.each`, `result.chain.map`, `result.chain.to_a`, and
  `result.chain[0]` all work. `result.chain.first` / `result.chain.last` too.
- Replace `task.id` / `task.result` / `task.chain` (v1 Task instance
  accessors) with `result.tid` / `result` / `result.chain` off the returned
  Result.
- `rescue CMDx::SkipFault` / `rescue CMDx::FailFault` → `rescue CMDx::Fault`,
  then branch on `e.result.skipped?` / `e.result.failed?`.

## Pass 6 — Middlewares

- Rewrite every middleware `def call(task, options, &block)` to
  `def call(task)` and replace `block.call` with `yield`. Move any
  `options`-dependent configuration onto the middleware instance via
  `initialize`.
- Middlewares must NOT return the result or mutate `result.metadata`. Write
  observability data onto `task.context`, or emit it from a Telemetry
  subscriber on `:task_executed`.
- In every middleware, ensure `yield` runs on every code path — including
  `rescue` and `ensure`. Skipping `yield` raises `CMDx::MiddlewareError`.
- Procs/lambdas used as middleware must declare `&next_link` explicitly and
  call `next_link.call` (never `yield` — it targets the enclosing method).
- Delete registrations of `CMDx::Middlewares::Correlate`, `Runtime`, and
  `Timeout` — the classes are removed. If the project depended on them,
  replace with a short custom middleware or a Telemetry subscriber on
  `:task_started` / `:task_executed`.
- Update `register :middleware, SomeClass, foo: 1` to
  `register :middleware, SomeClass.new(foo: 1)`. The registry no longer
  auto-instantiates classes or forwards `**options`.

## Pass 7 — Configuration

- In `CMDx.configure` blocks and per-task `settings(...)` calls, delete:
  `task_breakpoints`, `workflow_breakpoints`, `rollback_on`, `dump_context`,
  `freeze_results`, `backtrace`, `exception_handler`.
- Delete any `SKIP_CMDX_FREEZING` env-var references.
- Delete `dry_run: true` from execution calls and any `Chain#dry_run?` /
  `context.dry_run` reads.

## Pass 8 — Lifecycle (workflows, rollback)

- If a task defines a `rollback` method that was invoked manually from a
  middleware or callback, delete the manual dispatch — Runtime calls
  `rollback` automatically on failure.
- If a workflow class defines `def work`, delete it — workflows raise
  `ImplementationError` when `#work` is defined on the subclass. Convert the
  body to `task` / `tasks` declarations.

## Pass 9 — Errors iteration

- `errors.each` now yields `[key, Set<String>]`, not `[key, Array<String>]`.
  Code that expected `Array`-only methods on the value (`.push`, `<<`,
  index access) needs `set.to_a` or `errors[key]` (which returns an Array).

---

## Final self-verification

Run this grep from the project root:

```bash
rg --hidden \
  'task_breakpoints|workflow_breakpoints|rollback_on|dump_context|freeze_results|SKIP_CMDX_FREEZING|\.good\?|\.bad\?|cid[^=]|threw_failure\?|dry_run|attributes_schema|remove_attribute|remove_return|on_executed|on_good|on_bad|cmdx\.returns\.missing|cmdx\.faults\.(invalid|unspecified)|CMDx::Executor|CMDx::Middlewares::(Correlate|Runtime|Timeout)|CMDx::(SkipFault|FailFault|UndefinedMethodError)|register\s+:attribute|attribute\s+:'
````

Every hit is either (a) a string/comment that should be updated, or (b) unfinished migration. Classify and either fix or report.

## Exit contract

Stop when BOTH of these hold:

1. `bundle exec rspec` exits 0.
1. The final self-verification grep returns no hits (excluding the migration doc itself, tests that deliberately assert v1→v2 deltas, and `CHANGELOG.md`).

If either fails and you can't resolve it from the rules above, stop and report the failing file:line with a one-line diagnosis.

````

## Future

The v2 internals open the door to a number of additions that didn't fit the rewrite. The list below is **planned, not committed** — semantics may shift before they ship.

### Infrastructure primitives

- **`CMDx::Stores`** — pluggable KV with `get` / `set` / `incr` / `del` + TTL. Memory and Redis adapters substrate `idempotent_by`, rate limiting, circuit breakers, checkpoints, and result caching.
- **`CMDx::Cache`** — `cache_result key: ->(t) { … }, ttl: 60` memoizes a successful result per-input on the configured store.
- **`CMDx::Locks`** — `lock_with key: …, ttl: …, wait: …` serializes executions. Distinct from idempotency: the latter says "don't retry", the former says "don't run concurrently".

### Tasks

- **`idempotent_by`** — declarative idempotency keyed off context: `idempotent_by :payment_id, ttl: 5.minutes`. Backed by `CMDx::Stores`.
- **`circuit_break`** — `circuit_break threshold: 5, cool_off: 30.seconds` without bolting on Stoplight per task.
- **`concurrency_limit`** — global bulkhead capping simultaneous executions of a task class.
- **`execute_async`** — returns a `Concurrent::Promise`-shaped future without forcing the caller to wrap in `Async { }`.
- **Background-job adapter** — `Task.perform_async` / `perform_in` / `perform_at` over Sidekiq, ActiveJob, or GoodJob, with JSON-safety enforced at enqueue time. Replaces the per-app Sidekiq mixin recipe.

### Workflows

- **Checkpoint/resume** — persist `context` after each group to a pluggable store so a restarted workflow skips completed groups. Pairs with `idempotent_by`.

### Observability / tooling

- **`Chain#to_mermaid` / `#to_dot`** — render a chain (with result statuses) for debugging deeply nested executions.
- **`Chain#timeline`** — Gantt-shaped `(task, start, end, status)` rows usable directly in dashboards. The data exists; only the assembly is missing.
- **`Result#pretty_print`** — REPL-friendly multi-line formatter with color and child indentation; the current single-line `to_s` gets noisy at depth.```
````
