<div align="center">
  <img src="./src/cmdx-light-logo.png#gh-light-mode-only" width="200" alt="CMDx Logo">
  <img src="./src/cmdx-dark-logo.png#gh-dark-mode-only" width="200" alt="CMDx Logo">

  ---

  Build business logic that’s powerful, predictable, and maintainable.

  [Documentation](https://drexed.github.io/cmdx) · [Changelog](./CHANGELOG.md) · [Report Bug](https://github.com/drexed/cmdx/issues) · [Request Feature](https://github.com/drexed/cmdx/issues)

  <img alt="Version" src="https://img.shields.io/gem/v/cmdx">
  <img alt="Build" src="https://github.com/drexed/cmdx/actions/workflows/ci.yml/badge.svg">
  <img alt="License" src="https://img.shields.io/github/license/drexed/cmdx">
</div>

# CMDx

Say goodbye to messy service objects. CMDx helps you design business logic with clarity and consistency—build faster, debug easier, and ship with confidence.

## Requirements

- Ruby: MRI 3.1+ or JRuby 9.4+.

CMDx does not require any framework. It supports Rails out of the box, but can be used with any framework.

## Installation

```sh
gem install cmdx
# - or -
bundle add cmdx
```

## Quick Example

Here's how a quick 4 step process can open up a world of possibilities:

### 1. Compose

```ruby
# Example represents a kitchen-sink task
# (checkout docs for minimum viable task example)

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

## Ecosystem

- [cmdx-rspec](https://github.com/drexed/cmdx-rspec) - RSpec test matchers

For backwards compatibility of certain functionality:

- [cmdx-i18n](https://github.com/drexed/cmdx-i18n) - 85+ translations, `v1.5.0` - `v1.6.2`
- [cmdx-parallel](https://github.com/drexed/cmdx-parallel) - Parallel workflow tasks, `v1.6.1` - `v1.6.2`

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/drexed/cmdx. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the CMDx project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).
