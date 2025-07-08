# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [TODO]

- Add table and pretty_table log formatters
- Add method and proc style validations
- Refactor parameter modules and classes for more robust usages
- Update `callback` and `middleware` to be module based

## [Unreleased]

### Changed
- Moved `Task::CALLBACKS` constant to `CallbackRegistry::TYPES`

## [1.0.1] - 2025-07-07

### Added
- Added comprehensive internationalization support with 24 language locales
  - Arabic, Chinese, Czech, Danish, Dutch, English, Finnish, French, German, Greek
  - Hebrew, Hindi, Italian, Japanese, Korean, Norwegian, Polish, Portuguese
  - Russian, Spanish, Swedish, Thai, Turkish, Vietnamese
- Added TLDR sections to documentation for improved accessibility

### Changed
- Improved configuration template with better defaults and examples

## [1.0.0] - 2025-07-03

### Added
- Added `Hook` class for flexible callback management
- Added `perform!` and `perform` method aliases for class-level `call!` and `call` methods
- Added comprehensive YARDoc documentation throughout codebase
- Added configuration-based hook registration system
- Added Cursor and GitHub Copilot configuration files for enhanced IDE support
- Added middleware support for tasks enabling extensible request/response processing
- Added pattern matching support for result objects
- Added support for direct instantiation of Task and Workflow objects
- Added Zeitwerk-based gem loading for improved performance and reliability

### Changed
- Changed `ArgumentError` to `TypeError` for type validation consistency
- Changed configuration from hash-based to PORO (Plain Old Ruby Object) class structure
- Improved documentation readability, consistency, and completeness
- Improved test suite readability, consistency, and coverage
- Renamed `Batch` to `Workflow` to better reflect functionality
- Renamed `Hook` to `Callback` for naming consistency
- Renamed `Parameters` to `ParameterRegistry` for clarity
- Renamed `Run` and associated components to `Chain` for better semantic meaning
- Updated `Chain` to use thread-based execution instead of context passing
- Updated `Immutator` to use `SKIP_CMDX_FREEZING` environment variable instead of `RACK_ENV`/`RAILS_ENV`
- Updated hooks from a hash structure to registry pattern

### Removed
- Removed deprecated `task_timeout` and `batch_timeout` configuration settings

## [0.5.0] - 2025-03-21

### Added
- Added `on_[state]` and `on_[status]` based result callback handlers
- Added `on_executed` state hook for task completion tracking
- Added `on_good` and `on_bad` status hooks for success/failure handling
- Added `state`, `status`, `outcome`, and `runtime` fields to run serializer
- Added `to_a` alias for array of hashes serializers

### Changed
- Reordered status and state hook execution for more predictable behavior

## [0.4.0] - 2025-03-17

### Added
- Added ANSI color utility for enhanced terminal output
- Added JSON string parsing support in array coercion
- Added JSON string parsing support in hash coercion

### Changed
- Improved ANSI escape sequence handling
- Improved run inspector output formatting

### Fixed
- Fixed log settings assignment when logger is nil to prevent errors

## [0.3.0] - 2025-03-14

### Added
- Added `LoggerSerializer` for standardized log output formatting
- Added `progname` support for logger instances

### Changed
- Removed `pid` (process ID) from result serializer output
- Reverted default log formatter from `PrettyLine` back to `Line`

### Fixed
- Fixed `call!` method not properly marking failure state as interrupted
- Fixed serialization issues with frozen run objects

## [0.2.0] - 2025-03-12

### Added
- Added `PrettyJson` log formatter for structured JSON output
- Added `PrettyKeyValue` log formatter for key-value pair output
- Added `PrettyLine` log formatter for enhanced line-based output

### Changed
- Renamed `DatetimeFormatter` utility to `LogTimestamp` for better clarity
- Renamed `MethodName` utility to `NameAffix` for better clarity
- Renamed `Runtime` utility to `MonotonicRuntime` for better clarity
- Updated `PrettyLine` to be the default log formatter
- Updated result logger to be wrapped in `Logger#with_logger` block for better context

### Fixed
- Fixed error when logging non-hash values
- Fixed fault bubbling behavior with nested halted calls

## [0.1.0] - 2025-03-07

### Added
- Initial release
