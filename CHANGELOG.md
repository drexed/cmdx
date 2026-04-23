# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - UNRELEASED

Full runtime rewrite: the v1 state-machine plus Zeitwerk architecture is replaced by an explicit signal-based runtime, immutable results, fiber-local chains, and a slimmer registry surface. See [docs/v2-migration.md](docs/v2-migration.md) for the full upgrade guide.

### Added
- Add `xid` correlation id on `Chain`, `Result`, and `Telemetry::Event`, sourced once per root execution from `CMDx.configuration.correlation_id` (a callable). Useful for threading external ids like Rails `request_id` through every task in a chain so they can be filtered together in logs/telemetry.
- Add `Context#as_json` / `Context#to_json` — JSON serialization delegating to `#to_h`
- Add `Errors#as_json` / `Errors#to_json` — JSON serialization delegating to `#to_h`
- Add `Result#as_json` / `Result#to_json` — JSON serialization delegating to the memoized `#to_h`
- Add `Input#as_json` / `Input#to_json` — JSON serialization delegating to `#to_h`
- Add `Output#as_json` / `Output#to_json` — JSON serialization delegating to `#to_h`
- Add `CMDx::Signal` halt token thrown via `catch(Signal::TAG)` (`:cmdx_signal`)
- Add `Signal#ok?` / `Signal#ko?` predicates
- Add `CMDx::Runtime` orchestrating the full task lifecycle and building the final `Result`
- Add `CMDx::Telemetry` pub/sub for `:task_started`, `:task_deprecated`, `:task_retried`, `:task_rolled_back`, `:task_executed`; emits `Telemetry::Event` data objects with `cid`, `root`, `type`, `task`, `tid`, `name`, `payload`, `timestamp`
- Add `CMDx::Deprecation` for declarative class-level deprecation (`:log`, `:warn`, `:error`, Symbol, Proc, callable) with `:if` / `:unless` gating
- Add `CMDx::Input` / `CMDx::Inputs` (replaces `Attribute` / `AttributeRegistry` / `AttributeValue`) supporting `:source`, `:default`, `:transform`, `:as`, `:prefix` / `:suffix`, and nested children via DSL block
- Add `CMDx::Output` / `CMDx::Outputs` for first-class declared outputs verified against `task.context` after `work` (required-presence, default application, coercion, transformation, validation, write-back of final value); `:default` and `:transform` mirror input semantics — defaults fire for nil/absent values and can satisfy `:required`, transforms run between coerce and validate
- Add `CMDx::Util` single conditional-evaluation module (`evaluate`, `if?`, `unless?`, `satisfied?`) consolidating the v1 `Utils::*` modules
- Add `CMDx::I18nProxy` translation façade that delegates to `I18n` when available, otherwise loads the bundled YAML and percent-interpolates with memoization
- Add `CMDx::LoggerProxy` returning a per-task logger, `dup`-ing the base only when the task overrides `log_level` or `log_formatter`
- Add new exception classes: `DefinitionError`, `DeprecationError`, `ImplementationError`, `MiddlewareError`
- Add `Task#work` abstract method (raises `ImplementationError` when not defined)
- Add `Task#rollback` lifecycle hook, auto-invoked by Runtime on failed results when defined; surfaced via `Result#rolled_back?` and the `:task_rolled_back` event
- Add `Task#success!` for signaling a successful halt, joining `skip!` / `fail!` / `throw!`
- Add `Task.execute` / `Task.execute!` as the execution entry points (aliased as `call` / `call!` for backward compatibility)
- Add `Task#execute(strict:)` instance method (aliased as `#call`)
- Add `Result#on(:success, :failed, ...)` chainable predicate-dispatch helper
- Add `Result#deconstruct` / `Result#deconstruct_keys` for pattern matching; `deconstruct` returns `#to_h.to_a` pairs and `deconstruct_keys(keys)` slices `#to_h` (`nil` returns the full hash)
- Add `Result#strict?`, `Result#deprecated?`, `Result#duration`, `Result#index`, `Result#root?`, `Result#backtrace`, `Result#errors`, `Result#tags`, `Result#origin`, and `Result#ctx` alias
- Add `Signal#origin` / `Result#origin` — upstream `Result` a signal/result was echoed from (`nil` for locally originated failures); set by `Task#throw!`, `Pipeline` when propagating workflow failures, and `Runtime` when rescuing a `Fault` inside `work`
- Add `Chain#unshift`, `Chain#root`, `Chain#state`, `Chain#status`, `Chain#last`, `Chain#freeze`; Runtime `unshift`s the root result (so `chain.root` and `chain[0]` point to the outermost task) and freezes the chain on root teardown
- Add `Fault.for?(*tasks)` and `Fault.matches?(&block)` anonymous matcher subclasses suitable for `rescue`
- Add `include Enumerable` to `Errors`, `Chain`, and `Context`, exposing `map`, `select`, `find`, `include?`, `to_a`, `any?`, `all?`, `group_by`, `partition`, etc.
- Add `Set`-backed deduping per key on `Errors`, plus `keys`, `each_key`, `each_value`, `count`, `delete`, `clear`, `full_messages`, `to_hash(full)`
- Add `Context#keys`, `values`, `empty?`, `size`, `delete`, `clear`, `eql?` / `==`, `hash`, `deep_dup`, `respond_to_missing?`, and `Context#merge` that accepts any context-like object
- Add `Coercions::Coerce` and `Validators::Validate` inline-callable handlers for `:coerce` / `:validate` hash entries; generic callables receive `(value, task)`, Symbol and Proc handlers still resolve against the task
- Add `Configuration#backtrace_cleaner` and `Configuration#telemetry`
- Add `Configuration#log_exclusions` (defaults to `[]`) and matching `Settings#log_exclusions` override — an array of `Result#to_h` keys to strip from the lifecycle log entry (e.g. `[:context, :metadata]`). When empty, `Runtime` logs the `Result` as before; otherwise it logs `result.to_h.except(*exclusions)`. Other consumers (telemetry, return values) see the full result
- Add `Configuration#strict_context` (defaults to `false`) and matching `Settings#strict_context` override, toggling `Context#strict`; when enabled, unknown dynamic reads (`ctx.missing`) raise `NoMethodError` instead of returning `nil` — `[]`, `fetch`, `dig`, `key?`, and `?` predicates stay lenient
- Add `CMDx.reset_configuration!` which clears global registry ivars on `Task` for clean test setup/teardown; subclasses that already cloned their registries are unaffected
- Add `:if` / `:unless` gates to `Callbacks#register` (Symbol, Proc, or any `#call`-able); per-event DSL helpers (`before_execution`, `on_success`, etc.) forward the options through
- Add `:if` / `:unless` gates to `Middlewares#register` (Symbol, Proc, or any `#call`-able); evaluated per task in `Middlewares#process` — skipped middlewares are bypassed and the chain continues
- Add `:if` / `:unless` gates to `Retry` / `Task.retry_on`; gate receives `(task, error, attempt)` and, when falsy, re-raises the exception instead of retrying (no further wait). Adds `Retry#condition_if` / `Retry#condition_unless` readers
- Add `Outputs#register` block DSL (`Outputs::ChildBuilder`) for nested outputs via `required` / `optional` / `output` / `outputs`, arbitrarily deep; `Output#children`, `Output#verify_from_parent`, and `:children` in `Output#to_h` / `Task.outputs_schema`. `Task.outputs` forwards the block
- Add `Context#deconstruct` / `Context#deconstruct_keys` for pattern matching
- Add `Errors#deconstruct` / `Errors#deconstruct_keys` for pattern matching
- Add `:executor` option to parallel task groups (`Workflow.tasks ..., strategy: :parallel, executor: :threads | :fibers | #call`); `:threads` is the default and preserves current behavior, `:fibers` dispatches via `Fiber.schedule` bounded by `:pool_size` (requires a `Fiber.scheduler` such as the `async` gem's — raises `RuntimeError` when none is installed), and a user-supplied callable matching `call(jobs:, concurrency:, on_job:)` is accepted. Unknown symbols raise `ArgumentError`
- Add `:merge_strategy` option to parallel task groups controlling how successful sibling contexts fold back into the workflow context: `:last_write_wins` (default, matches previous behavior), `:deep_merge` (recursive over `Hash` values), `:no_merge` (workflow context left untouched), or a callable `call(workflow_context, result)`. Merging always walks successful results in declaration order. Unknown symbols raise `ArgumentError`
- Add `CMDx::Executors` registry (built-ins: `:threads` → `Executors::Thread`, `:fibers` → `Executors::Fiber`) and `CMDx::Mergers` registry (built-ins: `:last_write_wins`, `:deep_merge`, `:no_merge`) exposed on `Configuration#executors` / `#mergers` and per-task via `Task.executors` / `Task.mergers` (dup-on-inherit); `Task.register(:executor, ...)` and `Task.register(:merger, ...)` (plus matching `deregister`) let apps plug in custom dispatch/merge strategies resolvable by name from `:executor` / `:merge_strategy`
- Add `Context#deep_merge` — in-place recursive `Hash`-value merge; scalar-vs-hash collisions follow last-write-wins. Used by the `:deep_merge` parallel merge strategy but also available directly

### Changed
- **BREAKING**: Rename `#call` → `#work` on task subclasses; `Task.execute` / `Task.execute!` are the new entry points (`call` / `call!` kept as aliases)
- **BREAKING**: `Result` is now frozen and read-only; all state lives in the embedded `Signal`, built once during `Runtime#finalize_result`
- **BREAKING**: Move `STATES` / `STATUSES` constants and the `initialized` / `executing` / `executed!` transitions from `Result` to `Signal::STATES` / `Signal::STATUSES` (only `complete` / `interrupted` and `success` / `skipped` / `failed` remain)
- **BREAKING**: Halt mechanism uses `catch(Signal::TAG)` + `throw` instead of mutating result state; `success!` / `skip!` / `fail!` / `throw!` are now private `Task` instance methods (no longer delegated through `Result`) and raise `FrozenError` when called after teardown
- **BREAKING**: `Chain` is now fiber-local (was thread-local), keyed on `Fiber[:cmdx_chain]`, with internal `Mutex` on `push` / `unshift`; root Runtime clears the chain on teardown
- **BREAKING**: `Result#chain` now returns the owning `Chain` object directly instead of its results array (use `result.chain.to_a` / `result.chain.results`, or iterate via `Chain`'s new Enumerable methods)
- **BREAKING**: Drive `Result#caused_failure` / `threw_failure` / `caused_failure?` / `thrown_failure?` off `Signal#origin` instead of `signal.cause`; `caused_failure` walks `origin` recursively to the originating leaf, `threw_failure` returns `origin || self`, `caused_failure?` is true when the result originated the failure chain, `thrown_failure?` is true when the result re-threw an upstream failure
- Generated input accessors are now plain instance methods backed by `@_input_<name>` ivars set during input resolution; outputs have no accessors and are read/written directly on `task.context`
- `Workflow` declares groups via `task` / `tasks` (still aliased) and supports `:strategy => :parallel`, `:pool_size`, `:fail_fast`, `:if` / `:unless` per group; defining `#work` on a workflow raises `ImplementationError`
- `Pipeline` gains a `:parallel` strategy with `:pool_size` (replacing the removed `Parallelizer`); parallel workers share the parent fiber's chain, each get a `deep_dup`-ed context, successful child contexts are merged back into the workflow's context, and the first failed result is echoed via `throw!` to halt the pipeline; opt-in `:fail_fast` drains pending tasks on the first failure (in-flight tasks still finish and successful contexts still merge)
- `Task.callbacks`, `Task.middlewares`, `Task.coercions`, `Task.validators`, `Task.executors`, `Task.mergers`, `Task.telemetry`, `Task.inputs`, `Task.outputs` lazy-clone from the superclass (or global `Configuration`) on first access — subclasses extend rather than replace
- `Settings` is now a frozen value object holding only `logger`, `log_formatter`, `log_level`, `log_exclusions`, `backtrace_cleaner`, `tags`, `strict_context`; every getter falls back to `CMDx.configuration`
- `Context.build` accepts anything that responds to `#context` (e.g. another `Task`), unwraps repeatedly, and only re-wraps frozen contexts; symbolizes hash keys via `#to_hash` / `#to_h`
- `Retry` becomes a value object; `Task.retry_on` accumulates exceptions and options across the inheritance chain via `Retry#build`; supports built-in jitter strategies (`:exponential`, `:half_random`, `:full_random`, `:bounded_random`) plus Symbol / Proc / callable; retry wraps `work` only (input resolution and output verification run once, outside the retry loop)
- All registries (`Callbacks`, `Middlewares`, `Coercions`, `Validators`, `Telemetry`, `Inputs`, `Outputs`) implement `initialize_copy` for cheap copy-on-write inheritance; `register` / `deregister` validate types up-front and raise `ArgumentError` on misuse
- `Coercions#coerce` returns a `Coercions::Failure` sentinel with an i18n message recorded on `task.errors`; when multiple declared coercion rules match none (and none were inline), an aggregated `cmdx.coercions.into_any` message is reported instead of the per-rule messages
- `Validators#validate` records a message on `task.errors` for each failed rule (the individual built-in validators return `Validators::Failure`)
- Extend `Validators::Numeric` and `Validators::Length` with `:gt` / `:lt` (strict comparison, with `:gt_message` / `:lt_message` overrides and `cmdx.validators.{numeric,length}.{gt,lt}` i18n keys), plus `:gte` / `:lte` / `:eq` / `:not_eq` aliases that normalize to `:min` / `:max` / `:is` / `:is_not`
- `Fault#initialize` takes a single `Result`; `task`, `context`, and `chain` delegate to it; `Runtime` raises `Fault.new(@result.caused_failure)` so `fault.task` always points at the originating leaf (including in workflows and nested `execute!` chains)
- `Runtime` finalizes the `Result` before `raise_signal!` so the `Fault` it raises always carries a fully-built `Result`
- `Result#to_h` / `to_s` / `deconstruct_keys` now include `:origin` (compact `{ task:, tid: }` hash, or `nil` for locally originated failures)
- **BREAKING**: `Result#deconstruct` now returns `#to_h.to_a` (array of `[key, value]` pairs) instead of the fixed `[type, task, state, status, reason, metadata, cause, origin]` tuple — update any array-pattern matches to use find-patterns (`in [*, [:status, "failed"], *]`)
- `Result#deconstruct_keys` now honors its `keys` argument — `nil` returns the full `#to_h`, a key list slices it; previously it always returned the full hash
- `Middlewares` registry entries are now `[callable, options.freeze]` tuples — callers that read `Task.middlewares.registry` directly must map `.first` to recover the callable
- Slim the locale file: remove `attributes.undefined`, `coercions.unknown`, `faults.invalid`, `faults.unspecified`, `returns.*`; rename `returns.missing` → `outputs.missing`; add `nil_value` to `length` / `numeric` validator messages
- Generators emit the new `def work` template; the install template documents the new middleware / callback / telemetry / coercion / validator registration shapes
- Slim `Configuration` to: `middlewares`, `callbacks`, `coercions`, `validators`, `telemetry`, `default_locale`, `strict_context`, `backtrace_cleaner`, `logger`, `log_level`, `log_formatter`
- `Configuration#log_level` and `Configuration#log_formatter` now default to `nil` — treat them as optional overrides on top of `config.logger` (the default `Logger` still carries `Logger::INFO` + `LogFormatters::Line.new`). `LoggerProxy` only `dup`s the logger when a non-nil override differs from the logger's own level/formatter, so swapping `config.logger` no longer requires also clearing these fields

### Removed
- **BREAKING**: Remove `Result::STATES = [INITIALIZED, EXECUTING, COMPLETE, INTERRUPTED]`, the `executed!` / `executing!` transitions, and the `executed?` / `initialized?` / `executing?` predicates
- **BREAKING**: Remove `Task#id`, `Task#result`, `Task#chain` direct accessors — read these off the `Result` returned by `execute`
- **BREAKING**: Remove `Result#threw_failure?` predicate (`result.thrown_failure?` remains, with semantics flipped — true when the result re-threw an upstream failure)
- **BREAKING**: Remove `Result#chain_id` — read it off the chain: `result.cid`
- **BREAKING**: `Result#to_h` no longer produces nested `caused_failure` / `threw_failure` hashes; failure references render as `{ task:, tid: }` and `to_s` formats them as `<TaskClass uuid>`
- Remove `CMDx::Executor` (replaced by `CMDx::Runtime`)
- Remove `CMDx::Attribute`, `CMDx::AttributeRegistry`, `CMDx::AttributeValue` (replaced by `Input` / `Inputs` and `Output` / `Outputs`)
- Remove `CMDx::Resolver` (value resolution is owned by `Input#resolve`)
- Remove `CMDx::Identifier` (Runtime / Chain use `SecureRandom.uuid_v7` directly)
- Remove `CMDx::Locale` (superseded by `I18nProxy`)
- Remove `CMDx::Deprecator` (superseded by `Deprecation` declared per task class)
- Remove `CMDx::Parallelizer` (parallelism now lives in `Pipeline#run_parallel`)
- Remove `CMDx::CallbackRegistry`, `CMDx::MiddlewareRegistry`, `CMDx::CoercionRegistry`, `CMDx::ValidatorRegistry` (replaced by the simpler `Callbacks`, `Middlewares`, `Coercions`, `Validators` plain classes)
- Remove `CMDx::Utils::Call`, `CMDx::Utils::Condition`, `CMDx::Utils::Format`, `CMDx::Utils::Normalize`, `CMDx::Utils::Wrap` (collapsed into `CMDx::Util`)
- Remove built-in `CMDx::Middlewares::Correlate`, `CMDx::Middlewares::Runtime`, `CMDx::Middlewares::Timeout` — register equivalents on `config.middlewares` if needed
- Remove `CMDx::Exception` file — `CMDx::Error` / `Exception` and friends are now defined in `lib/cmdx.rb`
- Remove Zeitwerk autoloading (replaced by explicit `require_relative` ordering in `lib/cmdx.rb`); drop `forwardable`, `pathname`, `timeout`, and `zeitwerk` requires
- Remove `CMDx.gem_path` top-level helper
- Remove `Configuration#task_breakpoints`, `Configuration#workflow_breakpoints`, `Configuration#freeze_results`, `Configuration#exception_handler`, and the `SKIP_CMDX_FREEZING` env var — failure halting is now intrinsic to Runtime via `Signal` and `execute!` strict mode
- Remove `Chain#dry_run?` and the `dry_run:` context flag

### Migration notes

See [docs/v2-migration.md](docs/v2-migration.md) for the full upgrade guide. At minimum:

- Rename `def call` → `def work`; `MyTask.call(ctx)` still works (aliased) but prefer `MyTask.execute(ctx)`
- Replace `register :attribute, ...` with `required :name, ...` / `optional :name, ...` / `output :name, ...`
- Replace `result.chain_id` with `result.cid`
- Replace `task.id` / `task.result` / `task.chain` with reads off the `Result` returned by `execute`
- Subscribe to lifecycle observability via `config.telemetry.subscribe(:task_executed) { |event| ... }` instead of the removed `Runtime` / `Correlate` middlewares

## [1.21.0] - 2026-04-09

### Added
- Add `strict` option to `Result#skip!` and `Result#fail!` to bypass breakpoint halting in `execute!`
- Add `dump_context` global/local setting to include `context` in `Task#to_h`
- Add `Result#success!` for annotating successful results
- Add `started_at` and `ended_at` to runtime middleware payload
- Add `keys`, `values`, `each`, `each_key`, `each_value` methods to context
- Add `subtasks` to returns tasks defined in a workflow

### Changed
- Move `faults.unspecified` locale key to `reasons.unspecified`

## [1.20.0] - 2026-03-12

### Added
- Add `CallbackRegistry#empty?` for fast callback presence checking
- Add `Parallelizer` class for bounded thread pool execution
- Add `Configuration#default_locale` setting (defaults to `"en"`)
- Add `Task.type` to return task mechanics
- Add `Utils::Normalize` module for exception and status normalization
- Add `Utils::Wrap` module for array value normalization
- Add `Retry` class for retry logic, state tracking, and jitter computation
- Add `Settings` object with method-based access
- Add `freeze_results` configuration option to replace `SKIP_CMDX_FREEZING` env var
- Add `any?`, `clear`, and `size` delegators to `Errors`
- Add `Context#respond_to_missing?` for setter methods
- Add `Attribute#clear_task_tree!` to prevent stale task instance retention
- Add thread-safe `Chain#push` and `Chain#index` via `Mutex`
- Add identity-aware `Executor#clear_chain!` for parallel execution safety
- Add `Executor#verify_middleware_yield!` to detect non-yielding middlewares
- Add copy-on-write semantics to `MiddlewareRegistry`, `CallbackRegistry`, `CoercionRegistry`, and `ValidatorRegistry`
- Add `Attribute#allocation_name` for task-free reader name resolution
- Add `AttributeRegistry#define_readers_on!` and `#undefine_readers_on!` for eager reader definition

### Changed
- Short-circuit `Executor#post_execution!` when callback registry is empty
- Optimize `Context#method_missing` to avoid `String` allocation on getter path
- Replace `parallel` gem with native `Parallelizer` thread pool
- Rename `in_threads` option to `pool_size`
- Move `TimeoutError` to `exception.rb` for Zeitwerk autoloading
- Update Rails initializer install script
- Dup attributes in `AttributeRegistry#define_and_verify` for thread-safe concurrent execution
- Default `retry_on` to `[StandardError, CMDx::TimeoutError]`
- Replace hash-based `settings[:]` with method-based `settings.` access
- Lazy-load locale translations instead of eager-loading
- Use compile-time method definition for `Identifier#generate` and `Chain`/`Correlate` `thread_or_fiber`
- Use `define_method` on task class for attribute readers
- Tighten `Deprecator` regex to exact word boundaries
- Use `public_send` instead of `send` in `Result` for state/status checks

### Fixed
- Fix `Attribute#source` and `#method_name` memoization without a task
- Fix `execute!` to call `executed!` before `post_execution!` on non-halt path
- Clear `task.errors` before each retry attempt
- Fix `Pipeline#execute_tasks_in_parallel` to snapshot context per thread
- Reject `in_processes` and `in_reactors` options in parallel tasks

### Removed
- Remove `SKIP_CMDX_FREEZING` env var in favor of `CMDx.configuration.freeze_results`

## [1.19.0] - 2026-03-09

### Changed
- Fall back attribute `source` to `:context` when no task is given
- Improve falsy attribute derived hash value lookup
- Freeze chain results
- Use `to_date`, `to_time`, `to_datetime` for date/time coercion checks

### Fixed
- Fix missing fault cause `NoMethodError`
- Fix validator `allow_nil` inverted logic
- Fix array coercion JSON parse error to return `CoercionError`
- Fix boolean coercions to return `false` for `nil` and `""`

## [1.18.0] - 2026-03-09

### Changed
- Use `Fiber.storage` instead of `Thread.current` for `Chain` and `Correlate` storage, with fallback to `Thread.current` for Ruby < 3.2, making them thread and fiber safe
- Clone shared logger in `Task#logger` when `log_level` or `log_formatter` is customized to prevent mutation of the shared instance
- Derive attribute values from source objects that respond to the attribute name (via `send`) as fallback when the source is not callable

## [1.17.0] - 2026-02-23

### Added
- Add `returns` macro for context output validation after task execution
- Add `remove_return`/`remove_returns` macro to remove declared returns (supports inheritance)
- Add array coercion for JSON `"null"` string as empty array
- Add hash coercion for JSON `"null"` string as empty hash
- Add attribute sourcing to support both string and symbol keys when sourcing/deriving from Hash

### Changed
- Include the source method in the required attribute error message

### Fixed
- Fix coercion to not fail on `nil` for optional attributes

## [1.16.0] - 2026-02-06

### Added
- Add `CMDx::Exception` alias for `CMDx::Error`

### Changed
- Rename `exceptions.rb` file to `exception.rb` (zeitwerk compatibility)
- Rename `faults.rb` file to `fault.rb` (zeitwerk compatibility)

## [1.15.0] - 2026-01-21

### Added
- Add attribute `Absence` validator
- Add attribute `:description` option

## [1.14.0] - 2026-01-09

### Added
- Add Ruby 4.0 compatibility
- Add `Context#clear!` method to remove all context data
- Add `Task.attribute_schema` class method for attribute introspection
- Add `#to_h` method for attribute serialization

### Changed
- **BREAKING**: Switch license from MIT to LGPLv3
- Replace `instance_eval` with `define_singleton_method` for attribute method definitions
- Move retry count from metadata to result object
- Exclude non-essential files from gem package

### Removed
- Remove public `Result#rolled_back!` method to hide internal implementation

## [1.13.0] - 2025-12-23

### Added
- Add rollback tracking and logging for task execution
- Add `dry_run` execution option with inheritance support for nested tasks
- Add `Context#delete` alias for `Context#delete!`
- Add `Context#merge` alias for `Context#merge!`

## [1.12.0] - 2025-12-18

### Changed
- Optimize logging ancestor chain lookup performance
- Use `String#chop` instead of range indexing for improved string performance
- Make boolean coercion `TRUTHY` and `FALSEY` patterns case-insensitive
- Enhance YARD documentation using `yard-lint` validation

### Removed
- Remove `handle_*` callback methods in favor of `on(*states_or_statuses)` for flexible state handling

## [1.11.0] - 2025-11-08

### Changed
- Add conditional requirement support for attribute validation
- Update specs to use new `cmdx-rspec` matcher naming conventions

## [1.10.1] - 2025-11-06

### Added
- Add YARDoc documentation to documentation site

### Removed
- Remove unused `Executor#repeator` method

## [1.10.0] - 2025-10-26

### Added
- Add `rollback` capability to undo operations based on status
- Add retry mechanism documentation

### Changed
- Extend `retry_jitter` option to accept symbols, procs, and callable objects

## [1.9.1] - 2025-10-22

### Added
- Add RBS inline type signatures
- Add YARDocs for `attr_reader` and `attr_accessor` methods

## [1.9.0] - 2025-10-21

### Added
- Add `transform` option for attribute value transformations
- Add optional failure backtrace output
- Add exception handling for non-bang execution methods
- Add automatic retry mechanism for execution durability
- Add `to_h` hash coercion support
- Add MkDocs configuration with Material theme

### Changed
- Improve task settings initialization performance
- Improve exception error message clarity
- Improve parent settings inheritance behavior
- Clean halt backtrace frames for better readability

### Removed
- Remove `Freezer` module; consolidate logic into `Executor#freeze_execution!`
- Remove `task` parameter from callback method signatures
- Remove `task` and `workflow` arguments from conditional checks
- Remove chain persistence after execution in specs

## [1.8.0] - 2025-09-22

### Changed
- Generalize locale values for `invalid` and `unspecified` faults
- Nest attribute error messages under `error` key in metadata
- Reorder Logstash formatter keys for consistency
- Improve error messaging for duplicate item definitions
- Return empty hash `{}` for `nil` hash coercion

## [1.7.5] - 2025-09-10

### Added
- Add `Context#fetch_or_store` method for atomic get-or-set operations
- Add `Result#ctx` alias for `Result#context`
- Add `Result#ok?` alias for `Result#good?`
- Add result deconstruction support for pattern matching

## [1.7.4] - 2025-09-03

### Added
- Add errors delegation from result object
- Add `Errors#full_messages` and `Errors#to_hash` methods

## [1.7.3] - 2025-09-03

### Changed
- Use generic validation reason values
- Move validation full message to `:full_message` key in metadata

## [1.7.2] - 2025-09-03

### Changed
- Set correlation ID before proceeding to subsequent execution steps

## [1.7.1] - 2025-08-26

### Added
- Add block yielding support to `execute` and `execute!` methods

## [1.7.0] - 2025-08-25

### Added
- Add workflow generator

### Changed
- Integrate `cmdx-parallel` functionality into core
- Integrate `cmdx-i18n` functionality into core

## [1.6.2] - 2025-08-24

### Changed
- Prefix railtie I18n with `::` for `CMDx::I18n` compatibility
- Switch to `cmdx-rspec` for matcher support

## [1.6.1] - 2025-08-23

### Changed
- Log task results before freezing execution state
- Rename `execute_tasks_sequentially` to `execute_tasks_in_sequence`

## [1.6.0] - 2025-08-22

### Added
- Add workflow task `:breakpoints` support

### Changed
- Rename `Worker` class to `Executor`
- Extract workflow execution logic into `Pipeline` class

## [1.5.2] - 2025-08-22

### Changed
- Rename workflow `execution_groups` attribute to `pipeline`

## [1.5.1] - 2025-08-21

### Changed
- Prefix locale I18n with `::` for `CMDx::I18n` compatibility
- Add safe navigation to length and numeric validators
- Fix railtie file path to reference correct directory

## [1.5.0] - 2025-08-21

### Changed
- **BREAKING**: Complete architecture redesign for improved clarity, transparency, and performance

## [1.1.2] - 2025-07-20

### Changed
- See git tags for changes between versions 0.1.0 and 1.1.2

## [0.1.0] - 2025-03-07

### Added
- Initial release
