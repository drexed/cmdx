## [Unreleased]

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
- Add ansi util
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
