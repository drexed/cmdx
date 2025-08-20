# CMDx

[![forthebadge](http://forthebadge.com/images/badges/made-with-ruby.svg)](http://forthebadge.com)
[![Gem Version](https://badge.fury.io/rb/cmdx.svg?icon=si%3Arubygems)](https://badge.fury.io/rb/cmdx)
[![CI](https://github.com/drexed/cmdx/actions/workflows/ci.yml/badge.svg)](https://github.com/drexed/cmdx/actions/workflows/ci.yml)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=shields)](http://makeapullrequest.com)

`CMDx` is a Ruby framework for building maintainable, observable business logic through composable command objects. Design robust workflows with automatic attribute validation, structured error handling, comprehensive logging, and intelligent execution flow control that scales from simple tasks to complex multi-step processes.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cmdx'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cmdx

## Quick Example

```ruby
# Setup task
# ---
class SendWelcomeEmail < CMDx::Task
  register :middleware, CMDx::Middlewares::Correlate, id: -> { request.request_id }

  on_success :track_email_delivery!

  required :user_id, type: :integer, numeric: { min: 1 }
  optional :template, default: "customer"

  def work
    if user.nil?
      fail!("User not found", code: 404)
    elsif user.unconfirmed?
      skip!("Email not verified")
    else
      context.message = UserMailer.welcome(user, template).deliver_now
      context.sent_at = Time.now
    end
  end

  private

  def user
    @user ||= User.find_by(id: user_id)
  end

  def track_email_delivery!
    user.update!(welcome_email_message_id: context.message.id)
  end
end

# Execute task
# ---
result = SendWelcomeEmail.execute(
  user_id: 123,
  "template" => "admin"
)

# Handle result
# ---
if result.success?
  puts "Welcome email sent at #{result.context.sent_at}"
elsif result.skipped?
  puts "Skipped: #{result.reason}"
elsif result.failed?
  puts "Failed: #{result.reason} with code: #{result.metadata[:code]}"
end
```

## Table of contents

- [Getting Started](docs/getting_started.md)
- Basics
  - [Setup](docs/basics/setup.md)
  - [Execution](docs/basics/execution.md)
  - [Context](docs/basics/context.md)
  - [Chain](docs/basics/chain.md)
- Interruptions
  - [Halt](docs/interruptions/halt.md)
  - [Faults](docs/interruptions/faults.md)
  - [Exceptions](docs/interruptions/exceptions.md)
- Outcomes
  - [Result](docs/outcomes/result.md)
  - [States](docs/outcomes/states.md)
  - [Statuses](docs/outcomes/statuses.md)
- Attributes
  - [Definitions](docs/attributes/definitions.md)
  - [Naming](docs/attributes/naming.md)
  - [Coercions](docs/attributes/coercions.md)
  - [Validations](docs/attributes/validations.md)
  - [Defaults](docs/attributes/defaults.md)
- [Callbacks](docs/callbacks.md)
- [Middlewares](docs/middlewares.md)
- [Logging](docs/logging.md)
- [Internationalization (i18n)](docs/internationalization.md)
- [Deprecation](docs/deprecation.md)
- [Workflows](docs/workflows.md)
- [Tips and Tricks](docs/tips_and_tricks.md)

## Ecosystem

The following gems are under development:

- `cmdx-i18n` I18n locales
- `cmdx-rspec` RSpec matchers
- `cmdx-minitest` Minitest matchers
- `cmdx-jobs` Background job integrations
- `cmdx-parallel` Parallel workflow task execution

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/drexed/cmdx. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the CMDx project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).
