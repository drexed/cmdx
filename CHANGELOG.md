# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### TODO
- Add `rescue_from` handler

### Added
- Add attribute `Absence` validator
- Add attribute `:description` option

## [1.14.0] - 2025-01-09

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
