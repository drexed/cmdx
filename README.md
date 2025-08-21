<p align="center">
  <img src="./src/cmdx-logo.png" width="200" alt="CMDx Logo">
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/gem/v/cmdx">
  <img alt="Build" src="https://github.com/drexed/cmdx/actions/workflows/ci.yml/badge.svg">
  <img alt="License" src="https://img.shields.io/github/license/drexed/cmdx">
</p>

# CMDx

CMDx is a framework for building maintainable business processes. It simplifies building task objects by offering integrated:

- Flow controls
- Composable workflows
- Comprehensive logging
- Attribute definition
- Validations and coercions
- And much more...

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

Here's how a quick 3 step process can open up a world of possibilities:

```ruby
# 1. Setup task
# ---------------------------------
class SendWelcomeEmail < CMDx::Task
  register :middleware, CMDx::Middlewares::Correlate, id: -> { Current.request_id }

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

# 2. Execute task
# ---------------------------------
result = SendWelcomeEmail.execute(
  user_id: 123,
  "template" => "admin"
)

# 3. Handle result
# ---------------------------------
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

The following gems are currently under development:

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
