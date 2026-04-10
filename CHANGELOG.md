# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - Complete Redesign

### Changed (BREAKING)
- **Signal-based control flow**: `fail!`, `skip!`, and `success!` now use `throw(:cmdx_signal)` / `catch(:cmdx_signal)` instead of raising `Fault` exceptions. ~3x faster for non-exceptional interruptions.
- **Immutable Result**: `Result` is now frozen on creation. All fields are `attr_reader` only. No more mutable state transitions.
- **Unified Runtime**: Replaced `Executor` + `Resolver` with a single `Runtime` orchestrator that owns the entire lifecycle.
- **Module-based Task composition**: Task is now composed from focused modules (`Signals`, attributes DSL, callbacks DSL, middleware DSL, returns DSL, settings DSL, execution class methods).
- **Task instance methods reduced to 9**: `context`/`ctx`, `logger`, `work`, `rollback`, `success!`, `skip!`, `fail!`, `throw!`, `dry_run?`. No more `id`, `result`, `chain`, `errors`, `attributes`, `resolver`.
- **Attribute readers via anonymous modules**: Attribute accessors are defined on included anonymous modules (visible in `ancestors`, overridable with `super`).
- **Outcome struct**: Internal mutable scratch pad (`Outcome`) used during execution, converted to frozen `Result` at the end.
- **No circular references**: `Result` stores `task_id` (String) and `task_class` (Class), never the task instance. Task never holds Result.
- **Callback signature**: Runtime injects `@_result` before callbacks, removes after. Class-based callbacks receive `(task, result)`.
- **Settings lazy delegation**: Per-task `Settings` delegates to parent then global `Configuration` via `resolved_*` methods.
- **COW registries**: All 5 registries (Attribute, Callback, Middleware, Validator, Coercion) use copy-on-write for safe inheritance.

### Added
- `CMDx::Signals` module with `success!`, `skip!`, `fail!`, `throw!`, `dry_run?`
- `CMDx::Outcome` struct for mutable execution tracking
- `CMDx::Runtime` single lifecycle orchestrator
- `CMDx::RetryStrategy` with configurable delay and jitter
- `CMDx::ValueResolver` pipeline: source → derive → default → coerce → transform
- `CMDx::Deprecator` with `:restrict` and `:warn` modes
- Full test suite (263 examples, 0 failures)

### Removed
- `CMDx::Executor` (replaced by `Runtime`)
- `CMDx::Resolver` (replaced by `Runtime`)
- `CMDx::AttributeValue` (replaced by `ValueResolver`)
- `CMDx::Retry` (replaced by `RetryStrategy`)
- Mutable `Result` state transitions
- Circular references between Task, Result, and Resolver
- Require `time` in `Coercions::Time` so `Time.parse` is available on Ruby 3.4+

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
