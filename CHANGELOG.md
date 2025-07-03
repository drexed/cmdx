## [Unreleased]

## [1.0.0] - 2025-07-03

### Added
- Zeitwerk gem loader
- Add middleware support for tasks
- Add Cursor and Copilot rules
- Add YARDoc documentation
- Add `perform!` and `perform` alias to class `call!` and `call`
- Allow direct instantiation of Task and Batch objects
- Add pattern matching of results
- Add a `Hook` class
- Add hooks via configuration
### Changed
- Changed configuration to be a PORO class
- Changed ArgumentError to TypeError where checking `is_a?`
- Improve documentation readability, consistency, completeness
- Improve test readability, consistency, completeness
- Renames `Parameters` to `ParameterRegistry`
- Convert hooks hash to a registry
- Rename `Run` and its associated items to `Chain`
- Convert `Chain` to use threads instead of passing context
- Immutator now uses a `SKIP_CMDX_FREEZING` env var instead of `RACK_ENV` or `RAILS_ENV`
- Rename `Hook` to `Callback`
- Rename `Batch` to `Workflow`
### Removed
- Removed configuration `task_timeout` and `batch_timeout`

## [0.5.0] - 2025-03-21

### Added
- Add `to_a` alias on array of hashes serializers
- Add `state`, `status`, `outcome`, and `runtime` to run serializer
- Add `on_[state]` and `on_[status]` based result callback handlers
- Add `on_executed` state task hook
- Add `on_good` and `on_bad` status task hook
### Changed
- Changed status and state hook order

## [0.4.0] - 2025-03-17

### Added
- Add ANSI util
- Add string to json parsing in hash coercion
- Add string to json parsing in array coercion
### Changed
- Skip assigning log settings if logger is nil
- Improve ANSI escape sequence
- Improve run inspector output

## [0.3.0] - 2025-03-14

### Added
- Add `progname` to logger instances
- Add `LoggerSerializer` to standardize log output
### Changed
- Revert default log formatter to `Line`
- Removed `pid` from result serializer
- Fix serialization of frozen run
- Fix `call!` not marking state of failure as interrupted

## [0.2.0] - 2025-03-12

### Added
- Add `PrettyJson` log formatter
- Add `PrettyKeyValue` log formatter
- Add `PrettyLine` log formatter
### Changed
- Make `PrettyLine` the default log formatter
- Rename `MethodName` util to `NameAffix`
- Rename `DatetimeFormatter` util to `LogTimestamp`
- Rename `Runtime` util to `MonotonicRuntime`
- Fix logging non hash values from raising an error
- Fix bubbling of faults with nested halted calls
- Wrap result logger in a `Logger#with_logger` block

## [0.1.0] - 2025-03-07

### Added
- Initial release
