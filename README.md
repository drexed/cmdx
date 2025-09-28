<div align="center">
  <img src="./src/cmdx-logo.png" width="200" alt="CMDx Logo">

  <h1>CMDx</h1>

  The CMDx frameworks guides building business logic without the chaos

  [Documents](./docs/getting_started.md) · [Changelog](./CHANGELOG.md) · [Report Bug][/pulls] · [Request Feature][github-issues-link]

  <img alt="Version" src="https://img.shields.io/gem/v/cmdx">
  <img alt="Build" src="https://github.com/drexed/cmdx/actions/workflows/ci.yml/badge.svg">
  <img alt="License" src="https://img.shields.io/github/license/drexed/cmdx">
</div>

## Framework Philosophy

Ditch the messy service objects. CMDx helps you design business processes with clarity and consistency—build faster, debug easier, and keep your sanity.

#### Compose, Execute, React, Observe (CERO) pattern

CMDx encourages breaking business logic into composable tasks. Each task can be combined into larger workflows, executed with standardized flow control, and fully observed through logging, validations, and context.

- **Compose** → Define small, contract-driven tasks with typed attributes, validations, and natural workflow composition.
- **Execute** → Run tasks with clear outcomes, intentional halts, and pluggable behaviors via middlewares and callbacks.
- **React** → Adapt to outcomes by chaining follow-up tasks, handling faults, or shaping future flows.
- **Observe** → Capture immutable results, structured logs, and full execution chains for reliable tracing and insight.

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

Here's how a quick 4 step process can open up a world of possibilities:

### 1. Compose

#### Minimum Viable Task

```ruby
class SendAnalyzedEmail < CMDx::Task
  def work
    user = User.find(context.user_id)
    MetricsMailer.analyzed(user).deliver_now
  end
end
```

#### Fully Featured Task

```ruby
class AnalyzeMetrics < CMDx::Task
  register :middleware, CMDx::Middlewares::Correlate, id: -> { Current.request_id }

  on_success :track_analysis_completion!

  required :dataset_id, type: :integer, numeric: { min: 1 }
  optional :analysis_type, default: "standard"

  def work
    if dataset.nil?
      fail!("Dataset not found", code: 404)
    elsif dataset.unprocessed?
      skip!("Dataset not ready for analysis")
    else
      context.result = PValueAnalyzer.execute(dataset:, analysis_type:)
      context.analyzed_at = Time.now

      SendAnalyzedEmail.execute(user_id: Current.account.manager_id)
    end
  end

  private

  def dataset
    @dataset ||= Dataset.find_by(id: dataset_id)
  end

  def track_analysis_completion!
    dataset.update!(analysis_result_id: context.result.id)
  end
end
```

### 2. Execute

```ruby
result = AnalyzeMetrics.execute(
  dataset_id: 123,
  "analysis_type" => "advanced"
)
```

### 3. React

```ruby
if result.success?
  puts "Metrics analyzed at #{result.context.analyzed_at}"
elsif result.skipped?
  puts "Skipping analyzation due to: #{result.reason}"
elsif result.failed?
  puts "Analyzation failed due to: #{result.reason} with code #{result.metadata[:code]}"
end
```

### 4. Observe

```log
I, [2022-07-17T18:42:37.000000 #3784] INFO -- CMDx:
index=1 chain_id="018c2b95-23j4-2kj3-32kj-3n4jk3n4jknf" type="Task" class="SendAnalyzedEmail" state="complete" status="success" metadata={runtime: 347}

I, [2022-07-17T18:43:15.000000 #3784] INFO -- CMDx:
index=0 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task" class="AnalyzeMetrics" state="complete" status="success" metadata={runtime: 187}
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
  - [Transformations](docs/attributes/transformations.md)
- [Callbacks](docs/callbacks.md)
- [Middlewares](docs/middlewares.md)
- [Logging](docs/logging.md)
- [Internationalization (i18n)](docs/internationalization.md)
- [Deprecation](docs/deprecation.md)
- [Workflows](docs/workflows.md)
- [Tips and Tricks](docs/tips_and_tricks.md)

## Ecosystem

- [cmdx-rspec](https://github.com/drexed/cmdx-rspec) - RSpec test matchers

For backwards compatibility of certain functionality:

- [cmdx-i18n](https://github.com/drexed/cmdx-i18n) - 85+ translations, `v1.5.0` - `v1.6.2`
- [cmdx-parallel](https://github.com/drexed/cmdx-parallel) - Parallel workflow tasks, `v1.6.1` - `v1.6.2`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/drexed/cmdx. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the CMDx project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).
