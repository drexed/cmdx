# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [UNRELEASED]

## [1.13.0] - 2025-12-23

### Added

- Added task execution rollback tracking and logging
- Added `dry_run` option to task execution with inheritance support for nested tasks
- Added context `delete` alias for `delete!`
- Added context `merge` alias for `merge!`

## [1.12.0] - 2025-12-18

### Added
- Added active record database transaction example
- Added Sentry error tracking example
- Added Redis idempotency example
- Added Flipper feature flag example

### Updated
- Remove `handle_*` methods and provide `on(*states_or_statuses)` method for more flexibility
- Optimize logging ancestor lookup
- Use chop instead of range for better string performance
- Update boolean coercion `TRUTHY` and `FALSEY` regexp to be case insensitive
- Improve YARD documentation with `yard-lint`

## [1.11.0] - 2025-11-08

### Updated
- Added conditionally required attributes options
- Update specs to use new `cmdx-rspec` matcher names

## [1.10.1] - 2025-11-06

### Added
- Added Sidekiq async integration example
- Added YARDoc documentation to docs site

### Removed
- Removed `Executor#repeator` method (never used)

## [1.10.0] - 2025-10-26

### Added
- Added `rollback` ability to undo on matching status
- Added documentation for retries
- Added Stoplight circuit breaker integration example

### Updated
- Updated `retry_jitter` option to support symbol, proc, and callables on top of fixed values

## [1.9.1] - 2025-10-22

### Added
- Added RBS inlines type signatures
- Added YARDocs for `attr_reader` and `attr_accessor` methods

## [1.9.0] - 2025-10-21

### Added
- Added `transform` option to attributes
- Added option to output failure backtraces
- Added exception handling for non-bang methods
- Added durability with automatic retries to execution
- Added `to_h` hash coercion support
- Added comprehensive MkDocs configuration with material theme

### Changed
- Improved performance of task settings setup
- Improved error messages for raised exceptions
- Improved inheritance of parent settings
- Cleaned halt backtrace frames for better readability

### Removed
- Removed `Freezer` module and moved logic into executor `freeze_execution!` method
- Removed task parameter from callback signature
- Removed task and workflow arguments from conditional checks
- Removed chain persistence after execution in specs

## [1.8.0] - 2025-09-22

### Changed
- Generalized locale values for fault `invalid` and `unspecified`
- Nested attribute error messages under `error` key within metadata
- Reordered logstash formatter keys for consistency
- Improved error message for already defined items
- Changed hash coercion for `nil` to return `{}`

## [1.7.5] - 2025-09-10

### Added
- Added `fetch_or_store` method to context
- Added `ctx` alias for context in result
- Added `ok?` alias for `good?` in result
- Added deconstruction values in result

## [1.7.4] - 2025-09-03

### Added
- Added errors delegation from result object
- Added `full_messages` and `to_hash` methods to errors

## [1.7.3] - 2025-09-03

### Changed
- Changed validation reasons to use generic values
- Moved validation full message string to `:full_message` key within metadata

## [1.7.2] - 2025-09-03

### Changed
- Changed correlation ID to be set before continuing to further steps

## [1.7.1] - 2025-08-26

### Added
- Added result yielding when block is given to `execute` and `execute!` methods

## [1.7.0] - 2025-08-25

### Added
- Added workflow generator

### Changed
- Ported `cmdx-parallel` changes into core
- Ported `cmdx-i18n` changes into core

## [1.6.2] - 2025-08-24

### Changed
- Prefixed railtie I18n with `::` for compatibility with `CMDx::I18n`
- Changed to use `cmdx-rspec` for matchers support

## [1.6.1] - 2025-08-23

### Changed
- Changed task results to be logged before freezing
- Renamed `execute_tasks_sequentially` to `execute_tasks_in_sequence`

## [1.6.0] - 2025-08-22

### Added
- Added workflow task `:breakpoints` support

### Changed
- Renamed `Worker` class to `Executor`
- Moved workflow `work` logic into `Pipeline`

## [1.5.2] - 2025-08-22

### Changed
- Renamed workflow `execution_groups` attribute to `pipeline`

## [1.5.1] - 2025-08-21

### Changed
- Prefixed locale I18n with `::` for compatibility with `CMDx::I18n`
- Added safe navigation to length and numeric validators
- Updated railtie file path to point to correct directory

## [1.5.0] - 2025-08-21

### Changed
- **BREAKING**: Revamped CMDx for improved clarity, transparency, and higher performance

## [1.1.2] - 2025-07-20

### Changed
- All changes between versions `0.1.0` and `1.1.2` should be reviewed within their respective git tags

## [0.1.0] - 2025-03-07

### Added
- Initial release
