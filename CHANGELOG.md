# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [TODO]
- Update exceptions with more info on how to fix the issue
- Add an examples lib showing of use cases (point to them in the docs)
- Add durability (retries) to execution
 - N-retries (3 default)
 - Backoff strategy
 - On specific errors

## [UNRELEASED]

- Add `transform` option to attributes
- Add option to output failure backtraces

## [1.8.0] - 2025-09-22

### Changes
- Generalize locale values for fault `invalid` and `unspecified`
- Nest attribute error messages under `error` key within metadata
- Reordered logstash formatter keys
- Improved already defined error message
- Hash coercion for `nil` returns `{}`

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

### Changes
- Return generic validation reason
- Move validation full message string to `:full_message` within metadata

## [1.7.2] - 2025-09-03

### Changes
- Correlation ID is set before continuing to further steps

## [1.7.1] - 2025-08-26

### Added
- Yield result if block given to `execute` and `execute!` methods

## [1.7.0] - 2025-08-25

### Added
- Workflow generator

### Changes
- Port over `cmdx-parallel` changes
- Port over `cmdx-i18n` changes

## [1.6.2] - 2025-08-24

### Changes
- Prefix railtie I18n with `::` to play nice with `CMDx::I18n`
- Use `cmdx-rspec` for matchers support

## [1.6.1] - 2025-08-23

### Changes
- Log task results before freezing
- Rename `execute_tasks_sequentially` to `execute_tasks_in_sequence`

## [1.6.0] - 2025-08-22

### Changes
- Rename `Worker` class to `Executor`
- Move workflow `work` logic into `Pipeline`
- Add workflow task `:breakpoints`

## [1.5.2] - 2025-08-22

### Changes
- Rename workflow `execution_groups` attribute to `pipeline`

## [1.5.1] - 2025-08-21

### Changes
- Prefix locale I18n with `::` to play nice with `CMDx::I18n`
- Safe navigate length and numeric validators
- Update railtie file path points to correct directory

## [1.5.0] - 2025-08-21

### Changes
- BREAKING - Revamp CMDx for clarity, transparency, and higher performance

## [1.1.2] - 2025-07-20

### Changed
- All items between versions `0.1.0` and `1.1.2` should be reviewed within its own tag

## [0.1.0] - 2025-03-07

### Added
- Initial release
