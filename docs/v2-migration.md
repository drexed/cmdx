# Upgrading from v1.x to v2.0

CMDx 2.0 is a full runtime rewrite. The public DSL — `required`, `optional`, callbacks, middlewares, `retry_on`, `settings`, `Workflow` / `task` — largely survives, but halt semantics, attribute/return declarations, middleware signatures, and most internal classes have changed.

!!! warning "Not a drop-in upgrade"

    Plan to touch every task class. Halt is now `throw`/`catch` instead of `Result` mutation, attributes became inputs (`type:` → `coerce:`), returns became outputs (with a full pipeline), middleware takes one argument and `yield`s, and the built-in middleware trio (`Correlate`, `Runtime`, `Timeout`) is gone.

!!! tip "Benchmarks"

    Halts are ~2.5× faster, workflow failures ~3×, allocations down 50–80%. See [`benchmark/RESULTS.md`](https://github.com/drexed/cmdx/blob/main/benchmark/RESULTS.md).

---

## Before You Begin

1. **Check requirements.** Ruby 3.3+ (MRI, JRuby, or TruffleRuby). See [Getting Started](getting_started.md#requirements).
2. **Pin your current version.** `gem "cmdx", "~> 1.21"` in the `Gemfile` — a quick rollback path if the upgrade stalls.
3. **Baseline the suite.** Run `bundle exec rspec` on v1.x once and save the output; a green suite is your "before" snapshot.
4. **Skim the changelog.** The `[2.0.0]` section of [`CHANGELOG.md`](https://github.com/drexed/cmdx/blob/main/CHANGELOG.md) lists every breaking change by category.
5. **Read this page top-to-bottom.** Each section is a recipe you can apply independently.

---

## TL;DR Cheat Sheet

| Area | v1.x | v2.0 |
|---|---|---|
| Halt mechanism | mutate `Result` state machine | `catch`/`throw` a frozen `Signal` |
| `Result` mutability | mutable (`initialized → executing → complete`) | read-only; options frozen on construction |
| Lifecycle owner | `CMDx::Executor` | `CMDx::Runtime` |
| Inputs | `attribute` / `attributes` with `type:` | `input` / `inputs` with `coerce:` |
| Outputs | `returns :user, :token` (presence check only) | `output :user, required: true, coerce: ...` (full pipeline) |
| Callbacks | `on_executed`, `on_good`, `on_bad` | drops `on_executed`; renames to `on_ok` / `on_ko` |
| Middleware signature | `call(task, options, &block)` | `call(task) { yield }` |
| Built-in middlewares | `Correlate`, `Runtime`, `Timeout` | removed — register your own |
| Lifecycle observability | middleware-based | `Telemetry` pub/sub with 5 events |
| Workflow parallelism | none / 3rd-party | `tasks ..., strategy: :parallel, pool_size: N` |
| Chain storage | thread-local | fiber-local (parallel-safe) |
| Breakpoints | `task_breakpoints` / `workflow_breakpoints` | removed — use `execute!` for strict mode |
| Loader | Zeitwerk | explicit `require_relative` |
| Pattern matching | n/a | `case result in [_, _, "complete", "success", *]` |
| `result.task` | task **instance** | task **class** |
| `result.chain` | results `Array` | `Chain` object (`Enumerable`) |

---

## Upgrade Workflow

1. **Bump the gem.** `bundle update cmdx` and run the suite to surface breakage.
2. **Fix configuration.** Drop removed keys (see [Configuration](#configuration)). `rails generate cmdx:install` regenerates the v2 initializer as a reference.
3. **Fix tasks category-by-category.** Inputs → Outputs → Callbacks → Middlewares → Result consumers. The [Automated Migration Prompt](#automated-migration-prompt) mechanizes most of this.
4. **Audit result-handling code** for state-machine assumptions (`result.executing?`, `result.metadata[:x] = ...`, `result.cid`, `result.good?` / `bad?`) and any breakpoint / strict-mode configuration.
5. **Move observability** (correlation IDs, runtime metrics, timeouts) to [Telemetry](#telemetry) subscribers or hand-rolled middlewares.
6. **Re-run the suite.** When green, delete dead helpers that papered over v1's rough edges (manual rollbacks, `dry_run:` flags, `SKIP_CMDX_FREEZING` toggles).
7. **Validate.** Run the grep list in [Validating the Migration](#validating-the-migration) to catch stragglers.

!!! tip

    Coming from < 1.21? Also rename `def call` to `def work` and class-level `.call` / `.call!` to `.execute` / `.execute!`. v2 keeps `.call` / `.call!` as aliases.

---

## Configuration

The `CMDx::Configuration` surface shrank. Breakpoints, rollback config, freezing, and exception handlers are gone; what remains is registries plus logging/locale.

### Removed Keys

| Removed | Replacement |
|---|---|
| `task_breakpoints`, `workflow_breakpoints` | Failure halting is intrinsic. Use `execute!` for strict mode, or gate halts in a middleware. |
| `rollback_on` | `Task#rollback` runs automatically on failure (see [Rollback](#rollback)). |
| `dump_context`, `freeze_results`, `backtrace`, `exception_handler` | Removed. |
| `SKIP_CMDX_FREEZING` env var | Removed. Teardown always freezes `task`, `errors`, and (for the root) `context` and `chain`. |

### v2 Surface

```ruby
CMDx.configure do |config|
  config.middlewares       # CMDx::Middlewares
  config.callbacks         # CMDx::Callbacks
  config.coercions         # CMDx::Coercions
  config.validators        # CMDx::Validators
  config.telemetry         # CMDx::Telemetry  (NEW)
  config.default_locale    # "en"
  config.backtrace_cleaner # ->(bt) { ... } or nil
  config.logger            # Logger instance
  config.log_level         # Logger::INFO
  config.log_formatter     # CMDx::LogFormatters::Line.new
end
```

!!! note

    `CMDx.reset_configuration!` is new — call it in test setup/teardown to wipe the global config and invalidate `Task`'s cached registries.

See [Configuration](configuration.md) for the full surface.

---

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

| v1 | v2 |
|---|---|
| `MyTask.execute(...).task` → instance | `result.task` → **class** (see [Result Consumers](#result-consumers)) |
| `task.id` | `result.tid` |
| `task.result` | `execute` returns the `Result` directly |
| `task.chain` | `result.chain` (a `Chain`, not an Array) |
| `task.dry_run?` | removed — `dry_run` is gone |

`task.context`, `task.errors`, and `task.logger` still exist on the instance during `work`.

---

## Halts

`success!` / `skip!` / `fail!` / `throw!` are private instance methods on `Task` that `throw(Signal::TAG, signal)`. Runtime's `catch` intercepts the signal and constructs the result once at the end.

```ruby
# v1 — mutated result.state, kept running unless you returned
# v2 — throws; unreachable after the call
def work
  fail!("invalid email", code: :bad_input)
  deliver(context)  # v1 could still hit this; v2 NEVER reaches this
end
```

Breaking changes:

- **Halts are terminating.** Code after them in `work` is unreachable.
- `result.fail!` / `result.skip!` are gone — halts live on `Task`, not delegated through `Result`.
- `success!` is new — halt `work` early while staying successful.
- Only `fail!` and `throw!` capture `caller_locations(1)` as the signal backtrace; `success!` and `skip!` do not. `Fault#backtrace` points at your call site, cleaned through `Settings#backtrace_cleaner` when present.
- `throw!(other_result)` is a no-op when `other_result` didn't fail (same as v1; now implemented as a `Signal.echoed` throw).
- Calling any halt method on a frozen task raises `FrozenError`.

See [Interruptions - Signals](interruptions/signals.md) for the full semantics.

---

## Inputs (was Attributes)

Rename `attribute` / `attributes` to `input` / `inputs`, and `type:` to `coerce:`. `required` / `optional` aliases are unchanged.

| v1 | v2 |
|---|---|
| `attribute :email, type: :string, required: true` | `input :email, coerce: :string, required: true` |
| `attributes :name, :role, type: :string` | `inputs :name, :role, coerce: :string` |
| `type: :integer` | `coerce: :integer` |
| `type: [:integer, :float]` | `coerce: %i[integer float]` |
| `type: { date: { strptime: "..." } }` | `coerce: { date: { strptime: "..." } }` |
| `remove_attribute :flag` | `deregister :input, :flag` |
| `MyTask.attributes_schema` | `MyTask.inputs_schema` (plus `MyTask.outputs_schema`, new) |

`source:` (`:context`, method name, Proc, lambda) and nested-input blocks are unchanged.

### Removed

- `Attribute`, `AttributeRegistry`, `AttributeValue`, `Resolver`, `Identifier` classes

See [Inputs - Definitions](inputs/definitions.md).

---

## Outputs (was Returns)

`returns` was a presence check. `output` runs through the same required/coerce/validate pipeline as inputs.

```ruby
# v1
returns :user, :token

# v2
output :user,  required: true
output :token, required: true,
               coerce:   :string,
               length:   { min: 32 }
```

Outputs run **after** `work` returns successfully (skipped if the task halted). A missing required output adds `outputs.missing` to `task.errors`, which Runtime converts into a failed signal.

### Removed

| Removed | Replacement |
|---|---|
| `returns :name` | `output :name, required: true` |
| `remove_returns :name` | `deregister :output, :name` |
| `cmdx.returns.missing` locale key | `cmdx.outputs.missing` |

See [Outputs](outputs.md) for the full pipeline.

---

## Callbacks

### Event Renames

| v1 | v2 |
|---|---|
| `before_validation`, `before_execution`, `on_complete`, `on_interrupted`, `on_success`, `on_skipped`, `on_failed` | unchanged |
| `on_executed` | **removed** — use `on_complete` + `on_interrupted`, or `on_ok` / `on_ko` |
| `on_good` | `on_ok` |
| `on_bad` | `on_ko` |

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

See [Callbacks](callbacks.md) for Proc-identity caveats and conditional gates.

---

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

| v1 | v2 |
|---|---|
| `register :middleware, TelemetryMiddleware` | `register :middleware, TelemetryMiddleware.new` |
| `register :middleware, MonitorMiddleware, service_key: ENV["KEY"]` | `register :middleware, MonitorMiddleware.new(service_key: ENV["KEY"])` |
| `register :middleware, AuditMiddleware, at: 0` | `register :middleware, AuditMiddleware.new, at: 0` |

### Built-ins Removed

| Removed | Replacement |
|---|---|
| `CMDx::Middlewares::Correlate` | 5-line proc that sets `context.correlation_id`, or a `:task_started` Telemetry subscriber |
| `CMDx::Middlewares::Runtime` | `result.duration` is built in; `:task_executed` Telemetry for richer payloads |
| `CMDx::Middlewares::Timeout` | wrap `yield` in your own `Timeout.timeout(n)` middleware |

### Deregistration

Middleware identity is by-reference — deregister with the exact instance you registered, or by index:

```ruby
deregister :middleware, audit_instance
deregister :middleware, at: 0
```

See [Middlewares](middlewares.md) for the full surface.

---

## Settings

`Settings` is a frozen value object. Per-task overrides cover logger, log formatter, log level, backtrace cleaner, and tags — nothing else. Registries live on the `Task` class itself.

```ruby
# v1                                   # v2
settings logger: MyLogger.new,         settings logger:            MyLogger.new,
         tags:   %i[critical],                  log_formatter:     CMDx::LogFormatters::JSON.new,
         task_breakpoints: %w[failed], # gone   log_level:         Logger::DEBUG,
         freeze_results:   false       # gone   backtrace_cleaner: ->(bt) { bt.reject { |l| l.include?("gems/") } },
                                                tags:              %i[critical]
```

`Settings#build(opts)` returns a new instance and does a flat `Hash#merge` — a subclass that overrides `tags:` **replaces** (not concatenates) the parent's. Every getter falls back to `CMDx.configuration` when the key is absent.

`MyTask.middlewares`, `.callbacks`, `.coercions`, `.validators`, `.telemetry`, `.inputs`, `.outputs` are class-level accessors that lazy-clone from the superclass (or global config) on first read. Subclasses extend — they never replace.

---

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

!!! note

    User-supplied `metadata:` hashes (passed to `success!` / `skip!` / `fail!`) are **not** deep-frozen — freeze them yourself before throwing if you need that guarantee.

### Predicate Renames

| v1 | v2 |
|---|---|
| `Result::STATES` (4 states) | `Signal::STATES` (2 states: `"complete"`, `"interrupted"`) |
| `result.initialized?`, `result.executing?`, `result.executed?` | **removed** — a `Result` only exists post-finalization |
| `result.complete?`, `result.interrupted?`, `result.success?`, `result.skipped?`, `result.failed?` | unchanged |
| `result.good?` | `result.ok?` |
| `result.bad?` | `result.ko?` |
| `result.chain_id` | `result.cid` |
| `result.task` (instance) | `result.task` (**class**) |
| `result.chain` (Array) | `result.chain` (`Chain`, Enumerable) |
| `result.threw_failure?` | `result.thrown_failure?` (semantics flipped: true only when this result re-threw an upstream failure) |

### New Surface

```ruby
result.on(:success) { |r| deliver(r.context) }    # predicate dispatch
      .on(:failed)  { |r| alert(r.reason) }
# Accepted keys: :complete :interrupted :success :skipped :failed :ok :ko

case result                                       # pattern matching
in [_, _, "complete", "success", *]              then ok!
in [_, _, _, "failed", reason, *]                then alert(reason)
in { task:, status: "failed", cause: }           then ...
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

See [Outcomes - Result](outcomes/result.md) for the full surface.

---

## Workflows

### Parallel Groups (NEW)

```ruby
class FanOutWorkflow < CMDx::Task
  include CMDx::Workflow

  task  LoadInvoice                              # sequential default
  tasks ChargeCard, EmailReceipt,
        strategy:  :parallel,                    # NEW
        pool_size: 4                             # NEW
  task  FinalizeOrder
end
```

- Each parallel worker `deep_dup`s the workflow context, runs its task, then merges its successful child context back into the workflow (on the parent thread, after all workers join).
- All workers share the parent's fiber-local `Chain` — each worker sets `Fiber[Chain::STORAGE_KEY]` on thread entry, and each result is pushed under a `Mutex`.
- After all workers finish, the first **by declaration index** failed result halts the pipeline via `throw!`. Successful contexts merge in index order; failed ones are discarded.

### Behavioral Changes

- Defining `#work` on a workflow raises `ImplementationError` — the check fires only for methods defined **on the workflow subclass itself**, so `Workflow#work` (the delegator) is fine.
- `:if` / `:unless` gate the entire group.
- `workflow_breakpoints` is gone — failure always halts the pipeline. To keep going on a skip, branch explicitly in a wrapping task or middleware.

See [Workflows](workflows.md).

---

## Chain

```ruby
# v1                             # v2
Thread.current[:cmdx_chain]      Fiber[:cmdx_chain]
chain.dry_run?                   # gone
                                 Chain.current, Chain.current=, Chain.clear  # accessors
```

`Chain` is fiber-local so parallel workers each see the same underlying chain. `push` and `unshift` are `Mutex`-synchronized. Runtime `unshift`s the root result and `push`es children, so `chain[0]` (and `chain.root`) is always the outermost task regardless of finalization order.

New in v2:

- `Chain#root`, `Chain#state`, `Chain#status` — delegate to the root result (`nil` when absent).
- `Chain#last` — most recently appended result.
- `Chain#freeze` — Runtime freezes the chain (and its results array) on root teardown; later mutations raise `FrozenError`.
- `Chain` `include`s `Enumerable`, so `chain.map(&:status)`, `chain.find(&:failed?)`, `chain.first(3)`, `chain.to_a` all work.

!!! warning "Important"

    `Result#chain` now returns the `Chain` itself, not its results array. Call `chain.id` for the uuid, `chain.to_a` for a plain array, or iterate directly via Enumerable.

---

## Faults & Exceptions

### Hierarchy

```text
CMDx::Error = CMDx::Exception    (StandardError)
├── CMDx::Fault
├── CMDx::DeprecationError
├── CMDx::DefinitionError        (NEW — duplicate input/output accessor)
├── CMDx::ImplementationError    (NEW — Task#work unoverridden, or Workflow#work defined)
└── CMDx::MiddlewareError        (NEW — middleware didn't yield)
```

`CMDx::UndefinedMethodError` is gone. Exception classes are now declared inline in `lib/cmdx.rb` (was `lib/cmdx/exception.rb`).

### Matcher API

```ruby
rescue Fault.for?(ProcessOrder, ChargeCard) => fault
  Alert.for(fault.task, fault.message)
end

rescue Fault.matches? { |f| f.result.metadata[:retryable] } => fault
  RetryQueue.push(fault)
end
```

### Construction

`Fault#initialize(result)` takes a `Result` (was `(task_class, signal)`). It derives the backtrace from `result.backtrace || result.cause&.backtrace_locations`, then runs it through `task.settings.backtrace_cleaner` when present. `fault.task`, `fault.context`, `fault.chain`, and `fault.result` are all exposed.

!!! note

    `SkipFault` / `FailFault` (v1) are gone. There's just `Fault` — distinguish via `fault.result.skipped?` / `fault.result.failed?`.

---

## Errors

Mostly compatible. Messages are stored in a `Set` per key, so duplicate messages on the same key are silently dropped. `Errors` `include`s `Enumerable`, iterating `[key, Set<String>]` pairs (not `Array`).

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

---

## Context

```ruby
context.merge(other)              # accepts Context, Hash, or anything to_h-able
context.retrieve(:foo) { compute } # fetch-or-store
context.delete(:foo)
context.clear
context.deep_dup
context.map { |k, v| ... }        # Enumerable
```

Dynamic accessors (`context.foo`, `context.foo = 1`, `context.foo?`) are unchanged. The root context is frozen by Runtime teardown; nested subtask contexts stay mutable while their parent runs. `context.dry_run` and the `dry_run: true` constructor flag are gone.

---

## Retries

Shape unchanged; implementation is now a value object that accumulates across inheritance.

```ruby
class FlakyTask < CMDx::Task
  retry_on Net::ReadTimeout, ConnectionPool::TimeoutError,
           limit:     4,
           delay:     0.5,
           max_delay: 5.0,
           jitter:    :exponential   # :exponential, :half_random, :full_random,
                                     # :bounded_random, Symbol, Proc, or any callable
end

class ChildTask < FlakyTask
  retry_on Errno::ECONNRESET         # accumulated; ChildTask retries on all 3
end
```

`Task.retry_on` with no exceptions returns the current (possibly inherited) `Retry`. See [Retries](retries.md).

---

## Deprecation

v1's `Deprecator` class is replaced by a class-level `deprecation` DSL.

```ruby
class LegacyImporter < CMDx::Task
  deprecation :warn                       # :log, :warn, :error, Symbol, Proc, or any #call-able
  # deprecation :error, if: -> { Rails.env.production? }
  # deprecation ->(task) { Sentry.capture_message("deprecated task run: #{task.class}") }

  def work
    # ...
  end
end
```

Runtime invokes the deprecation right before the task body runs, sets `result.deprecated?` to `true`, and emits `:task_deprecated`. With `:error`, it raises `DeprecationError` and the task never runs. See [Deprecation](deprecation.md).

---

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

!!! note

    v1 had no built-in rollback dispatch (`rollback_on` config existed but didn't invoke anything). If you wired rollback manually from a middleware or callback, drop the scaffolding.

---

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

| Event | Payload |
|---|---|
| `:task_started` | empty |
| `:task_deprecated` | empty |
| `:task_retried` | `{ attempt: Integer }` |
| `:task_rolled_back` | empty |
| `:task_executed` | `{ result: Result }` |

Every event carries a `Telemetry::Event` with `cid`, `root`, `type`, `task`, `tid`, `name`, `payload`, `timestamp`. Subscribe per-task via `MyTask.telemetry.subscribe(...)`. See [Configuration - Telemetry](configuration.md#telemetry).

---

## Locale & I18n

CMDx now ships `CMDx::I18nProxy`, which delegates to the `i18n` gem when loaded and falls back to bundled YAML otherwise. Default locale is `en`; override with `config.default_locale`.

### Key Renames

| v1 | v2 |
|---|---|
| `cmdx.attributes.required` ("must be accessible via the %{method} source method") | `cmdx.attributes.required` ("is required") |
| `cmdx.attributes.undefined` | removed |
| `cmdx.coercions.unknown` | removed |
| `cmdx.faults.invalid` | removed |
| `cmdx.faults.unspecified` | `cmdx.reasons.unspecified` |
| `cmdx.returns.missing` | `cmdx.outputs.missing` |
| — | `cmdx.validators.length.nil_value` (added) |
| — | `cmdx.validators.numeric.nil_value` (added) |

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

See [Internationalization](internationalization.md).

---

## Generators

`cmdx:install`, `cmdx:task`, and `cmdx:workflow` emit the v2 template shape:

```ruby
# v1 templates: def call ... end
# v2 templates:
class MyTask < ApplicationTask
  def work
    # Your logic here...
  end
end
```

Regenerate `cmdx:install` as a reference when migrating an initializer — it documents the v2 middleware / callback / telemetry / coercion / validator registration shapes.

---

## Removed Modules & Classes

| Removed | Replacement |
|---|---|
| `CMDx::Executor` | `CMDx::Runtime` |
| `CMDx::Attribute` / `AttributeRegistry` / `AttributeValue` | `CMDx::Input` + `CMDx::Inputs` |
| `CMDx::Resolver` | input resolution on `Input#resolve` |
| `CMDx::Identifier` | `SecureRandom.uuid_v7` |
| `CMDx::Locale` | `CMDx::I18nProxy` |
| `CMDx::Deprecator` | declarative `Task.deprecation` |
| `CMDx::Parallelizer` | `CMDx::Pipeline#run_parallel` (`strategy: :parallel`) |
| `CMDx::CallbackRegistry` | `CMDx::Callbacks` |
| `CMDx::MiddlewareRegistry` | `CMDx::Middlewares` |
| `CMDx::CoercionRegistry` | `CMDx::Coercions` |
| `CMDx::ValidatorRegistry` | `CMDx::Validators` |
| `CMDx::Utils::Call` / `Condition` / `Format` / `Normalize` / `Wrap` | `CMDx::Util` (conditional helpers only); `Array(x)` instead of `Wrap.array(x)` |
| `CMDx::Middlewares::Correlate` / `Runtime` / `Timeout` | see [Built-ins Removed](#built-ins-removed) |
| `CMDx::UndefinedMethodError` | `CMDx::ImplementationError` |
| `CMDx::SkipFault` / `FailFault` | `Fault` + `fault.result.skipped?` / `failed?` |
| Zeitwerk autoloading | explicit `require_relative` in `lib/cmdx.rb` — gem no longer requires `zeitwerk`, `forwardable`, `pathname`, `set`, or `timeout` |
| `CMDx.gem_path` and the module-method surface | gone |

---

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

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `NoMethodError: undefined method 'good?' for Result` | `result.good?` → `result.ok?`, `result.bad?` → `result.ko?` |
| `NoMethodError: undefined method 'chain_id'` | `result.chain_id` → `result.cid` |
| `NoMethodError: undefined method 'executed?' / 'executing?' / 'initialized?'` | Predicates removed; use `result.complete? \|\| result.interrupted?` |
| `CMDx::MiddlewareError: middleware did not yield the next_link` | A middleware's `rescue` / `ensure` / early-return path skipped `yield`. Yield on every code path. |
| `CMDx::ImplementationError: cannot define Workflow#work` | A workflow subclass defined `#work`. Delete it and move the body into `task` / `tasks` declarations. |
| `FrozenError: cannot throw signals` | `skip!` / `fail!` / `throw!` called on a frozen task (post-execution). Restructure to halt inside `work`. |
| `Translation missing: cmdx.returns.missing` | Rename locale key to `cmdx.outputs.missing`. Same for `cmdx.faults.unspecified` → `cmdx.reasons.unspecified`. |
| `ArgumentError: middleware must respond to #call` | A middleware class was registered instead of an instance. Pass `MyMiddleware.new(...)`. |
| `undefined method 'metadata=' for Result` | `result.metadata[:x] = ...` writes aren't allowed. Set `task.context.x` **before** the halt instead. |
| `Fault#task` is a class, not an instance | v2 behavior — `fault.result.task` is the class. Read instance-scoped data off `fault.context` / `fault.result.context`. |

---

## Rollback Plan

If the upgrade stalls:

1. `git revert` the migration branch.
2. Pin the gem: `gem "cmdx", "~> 1.21"`.
3. Restore any helpers you deleted (manual rollback dispatchers, breakpoint config, `dry_run` branches).

A handful of patterns are hard to shim under v1 once you've rewritten them — keep them in git history rather than trying to forward-port:

- Read-only `Result` access patterns (v1 `Result` is mutable, so nothing breaks if you leave guards in).
- `success!` calls (no v1 equivalent — replace with `return` or custom metadata).
- Parallel workflow groups (v1 has no first-class parallel strategy — fall back to running groups sequentially).
- Telemetry subscribers (wrap as v1 middlewares calling the same sinks).

---

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

- Replace `returns :a, :b` with one `output :a, required: true` /
  `output :b, required: true` per key. Leave room for future `coerce:` /
  validator options.
- Replace `remove_returns :name` with `deregister :output, :name`.

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
```

Every hit is either (a) a string/comment that should be updated, or
(b) unfinished migration. Classify and either fix or report.

## Exit contract

Stop when BOTH of these hold:

1. `bundle exec rspec` exits 0.
2. The final self-verification grep returns no hits (excluding the
   migration doc itself, tests that deliberately assert v1→v2 deltas, and
   `CHANGELOG.md`).

If either fails and you can't resolve it from the rules above, stop and
report the failing file:line with a one-line diagnosis.
````
