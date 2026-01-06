# CMDx

Build business logic that's powerful, predictable, and maintainable.

[![Version](https://img.shields.io/gem/v/cmdx)](https://rubygems.org/gems/cmdx)
[![Build](https://github.com/drexed/cmdx/actions/workflows/ci.yml/badge.svg)](https://github.com/drexed/cmdx/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/drexed/cmdx)](https://github.com/drexed/cmdx/blob/main/LICENSE.txt)

---

Say goodbye to messy service objects. CMDx (pronounced "Command X") helps you design business logic with clarity and consistency—build faster, debug easier, and ship with confidence.

!!! note

    Documentation reflects the latest code on `main`. For version-specific documentation, please refer to the `docs/` directory within that version's tag.

## Requirements

- Ruby: MRI 3.1+ or JRuby 9.4+.

CMDx works with any Ruby framework. Rails support is built-in, but it's framework-agnostic at its core.

## Installation

```sh
gem install cmdx

# - or -

bundle add cmdx
```

## Quick Example

Build powerful business logic in four simple steps:

### 1. Compose

=== "Full Featured Task"

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

=== "Minimum Viable Task"

    ```ruby
    class SendAnalyzedEmail < CMDx::Task
      def work
        user = User.find(context.user_id)
        MetricsMailer.analyzed(user).deliver_now
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

Ready to dive in? Check out the [Getting Started](getting_started.md) guide to learn more.

## Ecosystem

- [cmdx-rspec](https://github.com/drexed/cmdx-rspec) - RSpec test matchers

For backwards compatibility of certain functionality:

- [cmdx-i18n](https://github.com/drexed/cmdx-i18n) - 85+ translations, `v1.5.0` - `v1.6.2`
- [cmdx-parallel](https://github.com/drexed/cmdx-parallel) - Parallel workflow tasks, `v1.6.1` - `v1.6.2`

## Contributing

Bug reports and pull requests are welcome at <https://github.com/drexed/cmdx>. We're committed to fostering a welcoming, collaborative community. Please follow our [code of conduct](https://github.com/drexed/cmdx/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [LGPLv3 License](https://www.gnu.org/licenses/lgpl-3.0.html).
