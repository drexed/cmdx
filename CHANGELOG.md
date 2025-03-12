## [Unreleased]

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
- Wrap result logger in a `Logger#with_logger` block

## [0.1.0] - 2025-03-07
### Added
- Initial release
