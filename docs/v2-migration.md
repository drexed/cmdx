# Upgrading from v1.x to v2.0

Welcome to CMDx 2.0. Under the hood, almost everything was rebuilt for speed and clarity. The good news: the Ruby you already write — `required`, `optional`, callbacks, middleware, `retry_on`, `settings`, `Workflow` / `task` — still looks mostly familiar.

The catch: a few big ideas changed. Halts no longer poke at a mutable `Result`. Task inputs used to be called attributes; now they are inputs with `coerce:` instead of `type:`. “Returns” are now outputs with a bit more power. Middleware has a simpler signature. Some old built-ins and internal classes went away.

Take a breath. You are not expected to memorize this page in one sitting.

!!! warning "This is not a drop-in upgrade"

    Expect to open most of your task files at least once. In v2, halts use Ruby’s `throw` / `catch` instead of mutating `Result`. `attribute` → `input`, `type:` → `coerce:`, `returns` → `output`. Middleware is `call(task) { yield }` — one argument, always yield. The old built-in middleware helpers (`Correlate`, `Runtime`, `Timeout`) are removed; you wire your own or use Telemetry.

    Want a robot to do the boring parts? Scroll to [Automated Migration Prompt](#automated-migration-prompt), paste it into your AI tool, then tidy whatever it misses by hand.

!!! tip "Faster and lighter"

    Halts are roughly 2.5× faster, workflow failures about 3×, and allocations dropped ~50-80% (depending on usecase). Numbers live in [`benchmark/RESULTS.md`](https://github.com/drexed/cmdx/blob/main/benchmark/RESULTS.md).

---

## Before You Begin

Treat this like moving apartments: pack before you lift the couch.

1. **Confirm Ruby.** You need Ruby 3.3+ (MRI, JRuby, or TruffleRuby). Details: [Getting Started](getting_started.md#requirements).
2. **Keep an escape hatch.** Pin v1 in your `Gemfile` first, e.g. `gem "cmdx", "~> 1.21"`, so you can roll back if the upgrade needs more time.
3. **Save a green baseline.** On v1, run `bundle exec rspec` once and keep the output. That is your “before” photo.
4. **Peek at the changelog.** The `[2.0.0]` section in [`CHANGELOG.md`](https://github.com/drexed/cmdx/blob/main/CHANGELOG.md) lists breaks grouped by topic.
5. **Skim this page in order.** Each section stands alone, but reading top to bottom matches how most teams migrate.

---

## TL;DR Cheat Sheet

One screen of “what moved where”:

| Area | v1.x | v2.0 |
|---|---|---|
| Halt mechanism | mutate `Result` state machine | `catch`/`throw` a frozen `Signal` |
| `Result` mutability | mutable (`initialized → executing → complete`) | read-only; options frozen on construction |
| Lifecycle owner | `CMDx::Executor` | `CMDx::Runtime` |
| Inputs | `attribute` / `attributes` with `type:` | `input` / `inputs` with `coerce:` |
| Outputs | `returns :user, :token` (presence check only) | `output :user, default: ..., if: ...` (every declared output is implicitly required; defaults + guards are optional) |
| Callbacks | `on_executed`, `on_good`, `on_bad` | drops `on_executed`; renames to `on_ok` / `on_ko` |
| Middleware signature | `call(task, options, &block)` | `call(task) { yield }` |
| Built-in middlewares | `Correlate`, `Runtime`, `Timeout` | removed — register your own |
| Lifecycle observability | middleware-based | `Telemetry` pub/sub with 5 events |
| Workflow parallelism | none / 3rd-party | `tasks ..., strategy: :parallel, pool_size: N` |
| Chain storage | thread-local | fiber-local (parallel-safe) |
| Breakpoints | `task_breakpoints` / `workflow_breakpoints` | removed — use `execute!` for strict mode |
| Loader | Zeitwerk | explicit `require_relative` |
| Pattern matching | n/a | `case result in [*, [:status, "success"], *]` |
| `result.task` | task **instance** | task **class** |
| `result.chain` | results `Array` | `Chain` object (`Enumerable`) |

---

## Upgrade Workflow

A practical order that keeps surprises small:

1. **Bump the gem.** `bundle update cmdx`, then run tests. Red is normal; it tells you what to fix next.
2. **Fix configuration first.** Remove keys that no longer exist ([Configuration](#configuration)). `rails generate cmdx:install` prints a fresh v2 initializer you can copy ideas from.
3. **Fix tasks in layers.** Inputs, then outputs, then callbacks, then middleware, then anything that reads `Result`. The [Automated Migration Prompt](#automated-migration-prompt) automates a big chunk of that if you want help.
4. **Hunt old `Result` habits.** Look for `result.executing?`, writes to `result.metadata`, `result.good?` / `bad?`, and breakpoint-style config. v2’s `Result` is calmer and stricter.
5. **Recreate observability.** Correlation IDs, timing, timeouts — use [Telemetry](#telemetry) and/or your own middleware instead of the removed built-ins.
6. **Green tests, then cleanup.** Once the suite passes, delete v1-only shims (`dry_run:`, `SKIP_CMDX_FREEZING`, manual rollback hacks you no longer need).
7. **Run the straggler grep.** [Validating the Migration](#validating-the-migration) has a copy-paste command to catch leftovers.

---

## Configuration

v2 exposes less on `CMDx::Configuration`. Gone: breakpoints, rollback toggles, result freezing knobs, and the old exception-handler hooks. Still there: registries (middleware, callbacks, coercions, and friends) plus logging and locale.

### Removed Keys

| Removed | Replacement |
|---|---|
| `task_breakpoints`, `workflow_breakpoints` | Removed. |
| `rollback_on` | Removed. |
| `dump_context`, `freeze_results`, `backtrace`, `exception_handler` | Removed. |
| `SKIP_CMDX_FREEZING` env var | Removed. |

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

See [Configuration](configuration.md) for every option explained in one place.

---

## Task Definition

You still implement `def work`. If you forget, v2 raises `ImplementationError` (v1 called that `UndefinedMethodError`).

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

**How the pieces fit:** `MyTask.new(ctx).execute` hands a ready-made task instance to `Runtime`. Class methods `MyTask.execute` / `MyTask.execute!` are thin wrappers around that same path. If you are doing something custom, `Runtime.execute(task)` still exists for driving the lifecycle without the `Task` sugar.

### Removed Instance Accessors

Some things you used to read off the task instance after a run now live on the `Result`. That keeps one object as the “answer” from a run.

| v1 | v2 |
|---|---|
| `MyTask.execute(...).task` → instance | `result.task` → **class** (see [Result Consumers](#result-consumers)) |
| `task.id` | `result.tid` |
| `task.result` | `execute` returns the `Result` directly |
| `task.chain` | `result.chain` (a `Chain`, not an Array) |
| `task.dry_run?` | removed — `dry_run` is gone |

During `work`, you still have `task.context`, `task.errors`, and `task.logger` on the instance.

---

## Halts

Halts are how you stop `work` early: success, skip, fail, or re-throw someone else’s failure. In v2 they are private methods on `Task` (`success!`, `skip!`, `fail!`, `throw!`) that `throw` a small frozen `Signal`. `Runtime` uses `catch` around your task, turns that throw into a single finished `Result` at the end.

**Heads-up compared to v1:**

- You cannot call `result.fail!` or `result.skip!` anymore. Halts belong to the task while `work` runs, not to `Result` afterward.
- `success!` is new: exit early but count as a success (handy for “nothing to do” paths).
- `fail!` and `throw!` record a backtrace from where you called them. `success!` and `skip!` do not. `Fault#backtrace` still reflects your call site when a cleaner is configured in `Settings`.
- `throw!(other_result)` still does nothing useful if that result did not fail (same idea as v1; internally it is an echoed signal).
- If the task is already frozen, calling any halt raises `CMDx::FrozenTaskError` — usually a sign you are halting too late in the lifecycle.

Full story: [Interruptions - Signals](interruptions/signals.md).

---

## Inputs (was Attributes)

Think “arguments to the task,” not database columns. Rename `attribute` / `attributes` → `input` / `inputs`, and rename the option `type:` → `coerce:`. `required` / `optional` work the same as before.

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

These internal types went away or moved: `Attribute`, `AttributeRegistry`, `AttributeValue`, `Resolver`, `Identifier`. You should not need to reference them in app code.

### Bridge

Prefer not to touch every file today? You can alias the old names in a base class:

```
class ApplicationTask
  class << self
    alias attribute input
    alias attributes inputs
  end
end
```

See [Inputs - Definitions](inputs/definitions.md).

---

## Outputs (was Returns)

In v1, `returns` mostly meant “these keys must end up set on the context after `work`.” v2’s `output` keeps that idea — every declared output is expected unless you give a default or a guard — and adds optional `:default` and `:if` / `:unless`.

```ruby
# v1
returns :user, :token

# v2
output :user
output :token, default: -> { JwtService.encode(user_id: context.user.id) }
```

Outputs are checked **after** `work` finishes successfully (if you halted, outputs are skipped). If a required output is missing, you get `outputs.missing` in `task.errors`, and the run fails. A `:default` counts as “present” when it returns something other than `nil`.

### Removed

| Removed | Replacement |
|---|---|
| `returns :name` | `output :name` |
| `remove_returns :name` | `deregister :output, :name` |
| `cmdx.returns.missing` locale key | `cmdx.outputs.missing` |

### Bridge

Same trick as inputs — alias in a base class if you want the old word:

```
class ApplicationTask
  class << self
    alias returns outputs
  end
end
```

See [Outputs](outputs.md) for the full surface.

---

## Callbacks

Callbacks still fire around validation, execution, and completion. Only a few names changed so we do not sound like a noir film.

### Event Renames

| v1 | v2 |
|---|---|
| `before_validation`, `before_execution`, `on_complete`, `on_interrupted`, `on_success`, `on_skipped`, `on_failed` | unchanged |
| `on_executed` | removed |
| `on_good` | `on_ok` |
| `on_bad` | `on_ko` |

### Registration

Each event has a friendly DSL method (`on_success`, `on_failed`, …). The lower-level `register :callback, ...` form still works if you like spelling things out.

```ruby
class MyTask < CMDx::Task
  on_failed  :alert_team
  on_success ->(task) { Stats.bump(:ok) }
  on_success { Stats.bump(:ok) }                  # block form
  register :callback, :on_failed, :alert_team     # still supported
end
```

A handler can be a `Symbol` (method on the task), a `Proc` (runs with `instance_exec` on the task), or anything that responds to `#call` (called with the task). Typos in the event name or a weird handler shape raise `ArgumentError` early.

### Deregistration

```ruby
deregister :callback, :on_failed                 # drops every callback for :on_failed
deregister :callback, :on_failed, :alert_team    # drops only this entry (matched by ==)
```

See [Callbacks](callbacks.md) for Proc-identity caveats and conditional gates.

---

## Middlewares

Middleware is still “wrap the task run,” but the method signature got simpler so the runtime can stay fast and predictable.

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

**Lambdas are picky:** `yield` inside a `lambda` refers to the *outer* method, not the next middleware link. Pass the next link as a block argument instead:

```ruby
->(task, &next_link) { next_link.call }
proc { |task, &next_link| next_link.call }
```

**Rules of the road:**

- **No `options` hash** passed into `call`. Put options on `initialize` and keep them on the instance.
- **Do not return the `Result` yourself.** Wrap, `yield`, unwind — `Runtime` builds the result when the chain finishes.
- **Always `yield`.** If a path skips `yield`, you get `CMDx::MiddlewareError` and the task never runs.
- **You do not see the finished `Result` inside the chain.** Use `task.context` / `task.errors` while wrapping, or subscribe to Telemetry `:task_executed` for the full `Result`.

### Registration

You register something that already responds to `#call` — usually an **instance** (`MyMiddleware.new(...)`), not the class name alone. The registry no longer magically calls `.new` or forwards `**options` for you.

| v1 | v2 |
|---|---|
| `register :middleware, TelemetryMiddleware` | `register :middleware, TelemetryMiddleware.new` |
| `register :middleware, MonitorMiddleware, service_key: ENV["KEY"]` | `register :middleware, MonitorMiddleware.new(service_key: ENV["KEY"])` |
| `register :middleware, AuditMiddleware, at: 0` | `register :middleware, AuditMiddleware.new, at: 0` |

### Built-ins Removed

The gem used to ship three opinionated middlewares. They are gone so you pick exactly what “correlation id,” “timing,” and “timeout” mean for your app:

| Removed | Replacement |
|---|---|
| `CMDx::Middlewares::Correlate` | Built-in: configure `CMDx.configuration.correlation_id = -> { ... }` to surface `xid` on `Chain`/`Result`/`Telemetry::Event` (see [Configuration - Correlation ID](configuration.md#correlation-id-xid)) |
| `CMDx::Middlewares::Runtime` | `result.duration` is built in; `:task_executed` Telemetry for richer payloads |
| `CMDx::Middlewares::Timeout` | wrap `yield` in your own `Timeout.timeout(n)` middleware |

### Deregistration

Middleware is matched by **object identity** (same instance you registered) or by stack **index**:

```ruby
deregister :middleware, audit_instance
deregister :middleware, at: 0
```

See [Middlewares](middlewares.md) for the full surface.

---

## Settings

`Settings` is a small frozen object: think “overrides for this task class.” You can override logger, formatter, level, log exclusions, backtrace cleaner, tags, and strict-context behavior. Everything else (middleware registries, coercions, …) hangs off the **task class**, not `settings`.

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

`Settings#build(opts)` shallow-merges a hash into a copy. If a subclass sets `tags:`, it **replaces** the parent list — it does not append. Any setting you omit falls back to `CMDx.configuration`.

Class-level helpers like `MyTask.middlewares`, `.callbacks`, `.coercions`, `.validators`, `.telemetry`, `.inputs`, `.outputs` lazy-clone from the superclass (or global config) the first time you touch them. Subclasses **add**; they do not wipe the parent’s registries.

---

## Result Consumers

When `execute` returns, you hold a `Result`. In v2 it behaves more like a receipt: frozen fields, no sneaky writes after the fact.

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

    If you pass a `metadata:` hash into `success!` / `skip!` / `fail!`, CMDx does **not** deep-freeze it for you. Freeze it yourself first if you rely on immutability.

### Predicate Renames

v2 only builds a `Result` when the run is **done**, so the old “halfway through” predicates disappear. Use the table below as a straight v1 → v2 map:

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
| `result.threw_failure?` | `result.thrown_failure?` (**meaning changed:** `true` only when *this* result re-threw an upstream failure) |

### New Surface

A few quality-of-life APIs landed in v2 — chaining with `.on`, pattern matching on `Result`, and extra fields like `duration` / `retries`:

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

When tasks call other tasks, failures can chain. These helpers answer “who started the fire?” vs “who passed the bucket?”

```ruby
result.threw_failure   # origin || self (nearest upstream failed, or self when originator)
result.thrown_failure? # true only when this result re-threw an upstream failure
result.caused_failure  # walks `origin` to the root-cause leaf
result.caused_failure? # true when this result originated the failure
```

`Result#to_h` is simpler: it no longer walks nested failure objects forever. `origin`, `threw_failure`, and `caused_failure` show up as `{ task: Class, tid: uuid }`, and `to_s` prints a short `<TaskClass uuid>` style string.

More detail: [Outcomes - Result](outcomes/result.md).

---

## Workflows

Workflows still declare steps with `task` / `tasks`. The headline feature in v2 is **parallel groups** — run several child tasks at once and merge their context back safely.

### Parallel Groups (NEW)

```ruby
class FanOutWorkflow < CMDx::Task
  include CMDx::Workflow

  task  LoadInvoice
  tasks ChargeCard, EmailReceipt, strategy:  :parallel, pool_size: 4
  task  FinalizeOrder
end
```

- Each worker gets its **own copy** of the workflow context (`deep_dup`), runs one child task, then hands successful writes back to the parent after everyone finishes.
- Everyone still belongs to the **same logical chain**, stored in **fiber-local** storage so parallel threads do not step on each other. Results are appended under a `Mutex`.
- **`continue_on_failure: false` (default):** as soon as one sibling fails, the workflow stops scheduling new work. Tasks already running still finish; successful merges still apply. The failure that “wins” for halting is the first one **in the order you declared the tasks**.
- **`continue_on_failure: true`:** every scheduled task runs to the end. Failures collect in the workflow’s `errors` hash (keys look like `:"TaskClass.field"` for validation issues or `:"TaskClass.status"` for plain `fail!` reasons). The halt you bubble out is still the first failure **by declaration order**.
- Fine tuning: pick an `:executor` (`:threads` by default, `:fibers`, or your own callable), a `:merger` (`:last_write_wins`, `:deep_merge`, `:no_merge`, or custom), and whether to `continue_on_failure`. [Workflows - Parallel Execution](workflows.md#parallel-execution) has examples.

### Behavioral Changes

- Do **not** define `#work` on your workflow subclass — that now raises `ImplementationError`. (The built-in `Workflow#work` that delegates to the pipeline is still fine; only **your** subclass is forbidden.)
- `:if` / `:unless` on a group wraps the **whole** group.
- `workflow_breakpoints` is gone: a failure stops the train. If you want “keep going after a skip,” wrap the workflow in another task or middleware and branch yourself.

Full guide: [Workflows](workflows.md).

---

## Chain

The chain is the ordered list of results for nested calls. v1 stashed it on the thread; v2 uses **fibers** so parallel work stays honest.

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

Fibers let parallel branches share one logical chain without corrupting each other. `push` / `unshift` are mutex-protected. `Runtime` unshifts the root result and pushes children, so index `0` is always the outermost caller — even if inner tasks finish first.

**New helpers:**

- `Chain#root`, `#state`, `#status` — read-through to the root `Result` (or `nil` if empty).
- `Chain#last` — newest child.
- `Chain#freeze` — after the root finishes, the chain freezes; mutating it raises `FrozenError`.
- `Chain` includes `Enumerable`, so `map`, `find`, `first`, `to_a`, etc. all work.

!!! warning "Heads-up: `result.chain` type changed"

    `result.chain` is a `Chain` object now, not a raw `Array`. Use `chain.id` for the UUID, `chain.to_a` if you truly need an array, or iterate the chain directly — it behaves like a collection.

---

## Faults & Exceptions

CMDx raises normal Ruby exceptions you can rescue. A few names moved; a few new ones describe mistakes in definitions or middleware.

### Hierarchy

```text
CMDx::Error = CMDx::Exception    (StandardError)
├── CMDx::Fault
├── CMDx::DeprecationError
├── CMDx::DefinitionError        (NEW — conflicting input accessor, or empty workflow task group)
├── CMDx::ImplementationError    (NEW — Task#work unoverridden, or Workflow#work defined)
└── CMDx::MiddlewareError        (NEW — middleware didn't yield)
```

`CMDx::UndefinedMethodError` retired; use `ImplementationError` when a task forgot to implement `work`. Exception classes now live in `lib/cmdx.rb` instead of a separate `exception.rb` file.

### Matcher API

`Fault` ships little helpers so your `rescue` lines read like English:

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

`Fault` exposes `task`, `context`, `chain`, and `result` so you can log or retry with full context.

!!! note

    v1 had `SkipFault` and `FailFault`. v2 has one `Fault` type — ask `fault.result.skipped?` or `fault.result.failed?` when you need to branch.

---

## Errors

`Errors` is still the bag of validation messages, but it now behaves like a tiny collection (`Enumerable`). Each pair is `[key, Set<String>]` — sets dedupe messages automatically.

**New helpers:**

```ruby
errors.added?(:email, "is invalid")
errors.full_messages      #=> { email: ["email is invalid"] }
errors.to_hash(true)      # full_messages
errors.count              # total messages across all keys
errors.each_key { ... }
errors.each_value { ... }
```

`errors[:email]` still returns an `Array<String>` built from the internal set.

---

## Context

`Context` grew a few small utilities for merging, memoized reads, and cleanup — handy when workflows pass big blobs around.

```ruby
context.merge(other)               # accepts Context, Hash, or anything to_h-able
context.retrieve(:foo) { compute } # fetch-or-store
context.delete(:foo)
context.clear
context.deep_dup
context.map { |k, v| ... }         # Enumerable
```

Dynamic readers/writers (`context.user`, `context.user = value`) work like before. Predicate readers (`context.foo?`) were added so you can ask “is this set?” without remembering internal keys.

---

## Retries

`retry_on` looks the same in your task files. Behind the scenes it is now a tidy value object that stacks cleanly across subclasses (child classes add more exception types instead of fighting the parent).

```ruby
class FlakyTask < CMDx::Task
  retry_on Net::ReadTimeout, ConnectionPool::TimeoutError, limit: 4, delay: 0.5, max_delay: 5.0, jitter: :exponential
end

class ChildTask < FlakyTask
  retry_on Errno::ECONNRESET
end
```

See [Retries](retries.md) for full options.

---

## Deprecation

Instead of a standalone `Deprecator` object, you declare behavior right on the task with `deprecation`.

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

Runtime checks this right before `work` runs, marks `result.deprecated?`, and emits `:task_deprecated`. Severity `:error` raises `DeprecationError` and skips the body — handy when you want CI or staging to fail loudly on legacy tasks.

More patterns: [Deprecation](deprecation.md).

---

## Rollback

`rollback` is no longer something you wire by hand in middleware for the common case. If `work` blows up, `Runtime` calls `rollback` (when you define it), sets `result.rolled_back?`, and fires `:task_rolled_back`.

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

---

## Telemetry

In v1, “watch the runtime” often meant writing middleware that wrapped every task. v2 adds **Telemetry**: a tiny pub/sub bus with five events. Nothing runs if nobody is listening, so the default cost is basically free.

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

Each event is a `Telemetry::Event` (`cid`, `root`, `type`, `task`, `tid`, `name`, `payload`, `timestamp`). You can also subscribe on a single task class with `MyTask.telemetry.subscribe(...)`. [Configuration - Telemetry](configuration.md#telemetry) lists everything you can tweak.

---

## Locale & I18n

Translations now go through `CMDx::I18nProxy`: if the `i18n` gem is loaded, messages flow through it; otherwise CMDx falls back to its built-in YAML. Set `config.default_locale` if you are not `"en"`.

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

!!! note

    Most locale files moved out of this gem into [`cmdx-i18n`](https://github.com/drexed/cmdx-i18n) so translations can ship on their own cadence.

More: [Internationalization](internationalization.md).

---

## Generators

`rails g cmdx:install`, `cmdx:task`, and `cmdx:workflow` now scaffold the v2 shape — plain `def work` bodies without v1-only boilerplate.

```ruby
class MyTask < ApplicationTask
  def work
    # Your logic here...
  end
end
```

Regenerate `cmdx:install` when you want a fresh cheat sheet for initializer wiring (middleware, callbacks, telemetry, coercions, validators).

---

## Removed Modules & Classes

If grep says “uninitialized constant …,” this table is your map from old names to new homes:

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

Before you merge the upgrade branch, do three quick checks:

**1. Tests.** `bundle exec rspec` (or your runner) should be green. In Rails apps, reset CMDx config between examples so class-level registries do not leak:

```ruby
RSpec.configure do |c|
  c.before(:each) { CMDx.reset_configuration! }
end
```

**2. Grep for ghosts.** Any match below usually means “unfinished v1 → v2 edit”:

```bash
rg --hidden \
  'task_breakpoints|workflow_breakpoints|rollback_on|dump_context|freeze_results|SKIP_CMDX_FREEZING|\.good\?|\.bad\?|cid[^=]|threw_failure\?|dry_run|attributes_schema|remove_attribute|remove_return|on_executed|on_good|on_bad|cmdx\.returns\.missing|cmdx\.faults\.(invalid|unspecified)|CMDx::Executor|CMDx::Middlewares::(Correlate|Runtime|Timeout)|CMDx::(SkipFault|FailFault|UndefinedMethodError)|register\s+:attribute|attribute\s+:'
```

**3. Read one log line.** Successful runs print a compact hash with `cid`, `index`, `root`, `type`, `task`, `id`, `state`, `status`, `duration`. If you still see `initialized` or `executing`, something is logging a half-baked v1-shaped object.

Example shape (values will differ):

```text
cmdx: cid="0190..." index=0 root=true type="Task" task=MyTask tid="0190..." state="complete" status="success" reason=nil metadata={} duration=12.34 ...
```

---

## Troubleshooting

Quick fixes for the errors people hit first:

| Symptom | Fix |
|---|---|
| `NoMethodError: undefined method 'good?' for Result` | `result.good?` → `result.ok?`, `result.bad?` → `result.ko?` |
| `NoMethodError: undefined method 'chain_id'` | `result.chain_id` → `result.cid` |
| `NoMethodError: undefined method 'executed?' / 'executing?' / 'initialized?'` | Predicates removed; use `result.complete? \|\| result.interrupted?` |
| `CMDx::MiddlewareError: middleware did not yield the next_link` | A middleware's `rescue` / `ensure` / early-return path skipped `yield`. Yield on every code path. |
| `CMDx::ImplementationError: cannot define Workflow#work` | A workflow subclass defined `#work`. Delete it and move the body into `task` / `tasks` declarations. |
| `CMDx::FrozenTaskError: cannot call :<halt>! after the task has been frozen` | `skip!` / `fail!` / `throw!` called on a frozen task (post-execution). Restructure to halt inside `work`. |
| `CMDx::UnknownAccessorError: unknown context key :foo (strict mode)` | `strict_context: true` caught a typoed reader. Either fix the typo or set the key before reading. |
| `CMDx::UnknownEntryError: unknown coercion: ...` (or validator / executor / merger / retrier / deprecator / event) | Registry lookup against an unregistered name. Register it on `CMDx.configuration.<registry>` or fix the symbol. |
| `CMDx::UnknownLocaleError: unable to load <locale> translations` | `default_locale` does not resolve to a YAML file on the locale path. Add the file via `CMDx::I18nProxy.register(path)` or pick a bundled locale. |
| `Translation missing: cmdx.returns.missing` | Rename locale key to `cmdx.outputs.missing`. Same for `cmdx.faults.unspecified` → `cmdx.reasons.unspecified`. |
| `ArgumentError: middleware must respond to #call` | A middleware class was registered instead of an instance. Pass `MyMiddleware.new(...)`. |
| `undefined method 'metadata=' for Result` | `result.metadata[:x] = ...` writes aren't allowed. Set `task.context.x` **before** the halt instead. |
| `Fault#task` is a class, not an instance | v2 behavior — `fault.result.task` is the class. Read instance-scoped data off `fault.context` / `fault.result.context`. |

---

## Rollback Plan

Sometimes you need to pause halfway. That is fine.

1. Revert the migration commit(s) or branch (`git revert` / `git checkout` — whatever your team uses).
2. Pin CMDx again, e.g. `gem "cmdx", "~> 1.21"`.
3. Bring back any small helpers you deleted (manual rollback wiring, breakpoint YAML, `dry_run` branches).

A few v2-only ideas do not map cleanly back to v1. Keep the v2 version in git history instead of trying to polyfill:

- Treating `Result` as read-only (extra guards on v1 do not hurt).
- `success!` (no twin in v1 — use early `return` or stash data on `context`).
- Parallel workflow groups (run those steps one-by-one under v1, or wrap them yourself).
- Telemetry subscribers (re-express the same sinks as v1 middleware if you must roll back).

---

## Automated Migration Prompt

This block is written for an AI assistant, not humans — stiff voice on purpose. Paste it into Cursor, Claude Code, or similar **with your repo open**. It is idempotent: running it twice should not double-apply the same rewrite.

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

## Future

Everything below is **ideas on the roadmap**, not shipped promises. Names and APIs may move.

### Infrastructure primitives

- **`CMDx::Stores`** — a tiny key/value abstraction (`get` / `set` / `incr` / `del` + TTL) with in-memory and Redis-style adapters. Think shared scratch space for idempotency keys, rate limits, circuit breakers, checkpoints, and cached results.
- **`CMDx::Cache`** — `cache_result key: ->(t) { ... }, ttl: 60` memoizes a successful run keyed by inputs.
- **`CMDx::Locks`** — `lock_with key: ..., ttl: ..., wait: ...` prevents two workers from running the same logical task at once. Different from idempotency: locks fight concurrency; idempotency fights duplicate side effects.

### Tasks

- **`idempotent_by`** — declare a stable key from context so retries short-circuit safely.
- **`circuit_break`** — flip a task open/closed after repeated failures without bolting Stoplight into every class.
- **`concurrency_limit`** — cap how many instances of a task may run at once across the process.
- **`execute_async`** — return a future-like object instead of always blocking the caller.
- **Background-job adapter** — `perform_async` / `perform_in` / `perform_at` helpers for Sidekiq, ActiveJob, GoodJob, etc., with JSON-safe payloads at enqueue time.

### Workflows

- **Checkpoint / resume** — persist context after each step group so a restarted workflow can skip finished work (pairs nicely with `idempotent_by`).

### Observability / tooling

- **`Chain#to_mermaid` / `#to_dot`** — pretty diagrams for gnarly chains.
- **`Chain#timeline`** — rows of `(task, start, end, status)` for dashboards.
- **`Result#pretty_print`** — multi-line REPL output with indentation and optional color.

None of the above exists in the gem yet; treat it as a peek at where maintainers are thinking, not a contract.
