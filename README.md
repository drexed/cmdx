# CMDx

[![forthebadge](http://forthebadge.com/images/badges/made-with-ruby.svg)](http://forthebadge.com)

[![Gem Version](https://badge.fury.io/rb/cmdx.svg?icon=si%3Arubygems)](https://badge.fury.io/rb/cmdx)
[![CI](https://github.com/drexed/cmdx/actions/workflows/ci.yml/badge.svg)](https://github.com/drexed/cmdx/actions/workflows/ci.yml)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=shields)](http://makeapullrequest.com)

`CMDx` is a Ruby framework for building maintainable, observable business logic through composable command objects. Design robust workflows with automatic parameter validation, structured error handling, comprehensive logging, and intelligent execution flow control that scales from simple tasks to complex multi-step processes.

## Installation

**Prerequisites:** This gem requires Ruby `>= 3.1` to be installed.

Add this line to your application's Gemfile:

```ruby
gem 'cmdx'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cmdx

## Table of contents

- [Getting Started](https://github.com/drexed/cmdx/blob/main/docs/getting_started.md)
- [Configuration](https://github.com/drexed/cmdx/blob/main/docs/configuration.md)
- Basics
  - [Setup](https://github.com/drexed/cmdx/blob/main/docs/basics/setup.md)
  - [Call](https://github.com/drexed/cmdx/blob/main/docs/basics/call.md)
  - [Context](https://github.com/drexed/cmdx/blob/main/docs/basics/context.md)
  - [Run](https://github.com/drexed/cmdx/blob/main/docs/basics/run.md)
- Interruptions
  - [Halt](https://github.com/drexed/cmdx/blob/main/docs/interruptions/halt.md)
  - [Faults](https://github.com/drexed/cmdx/blob/main/docs/interruptions/faults.md)
  - [Exceptions](https://github.com/drexed/cmdx/blob/main/docs/interruptions/exceptions.md)
- Parameters
  - [Definitions](https://github.com/drexed/cmdx/blob/main/docs/parameters/definitions.md)
  - [Namespacing](https://github.com/drexed/cmdx/blob/main/docs/parameters/namespacing.md)
  - [Coercions](https://github.com/drexed/cmdx/blob/main/docs/parameters/coercions.md)
  - [Validations](https://github.com/drexed/cmdx/blob/main/docs/parameters/validations.md)
  - [Defaults](https://github.com/drexed/cmdx/blob/main/docs/parameters/defaults.md)
- Outcomes
  - [Result](#results)
  - [States](https://github.com/drexed/cmdx/blob/main/docs/outcomes/states.md)
  - [Statuses](https://github.com/drexed/cmdx/blob/main/docs/outcomes/statuses.md)
- [Hooks](https://github.com/drexed/cmdx/blob/main/docs/hooks.md)
- [Middlewares](https://github.com/drexed/cmdx/blob/main/docs/middlewares.md)
- [Batch](https://github.com/drexed/cmdx/blob/main/docs/batch.md)
- [Logging](https://github.com/drexed/cmdx/blob/main/docs/logging.md)
- [Tips & Tricks](https://github.com/drexed/cmdx/blob/main/docs/tips_and_tricks.md)
- [Example](https://github.com/drexed/cmdx/blob/main/docs/example.md)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/drexed/cmdx. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the CMDx project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/drexed/cmdx/blob/main/CODE_OF_CONDUCT.md).
