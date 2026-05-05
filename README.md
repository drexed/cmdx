<div align="center">
  <img src="./src/cmdx-light-logo.png#gh-light-mode-only" width="200" alt="CMDx Light Logo">
  <img src="./src/cmdx-dark-logo.png#gh-dark-mode-only" width="200" alt="CMDx Dark Logo">

  ---

  Build business logic that’s powerful, predictable, and maintainable.

  [Home](https://drexed.github.io/cmdx) ·
  [Documentation](https://drexed.github.io/cmdx/getting_started) ·
  [Blog](https://drexed.github.io/cmdx/blog) ·
  [Changelog](./CHANGELOG.md) ·
  [Report Bug](https://github.com/drexed/cmdx/issues) ·
  [Request Feature](https://github.com/drexed/cmdx/issues) ·
  [AI Skills](https://github.com/drexed/cmdx/blob/main/skills) ·
  [llms.txt](https://drexed.github.io/cmdx/llms.txt) ·
  [llms-full.txt](https://drexed.github.io/cmdx/llms-full.txt)

  <img alt="Version" src="https://img.shields.io/gem/v/cmdx">
  <img alt="Build" src="https://github.com/drexed/cmdx/actions/workflows/ci.yml/badge.svg">
  <img alt="License" src="https://img.shields.io/badge/license-LGPL%20v3-blue.svg">
</div>

# CMDx

Say goodbye to messy service objects. CMDx helps you design business logic with clarity and consistency—build faster, debug easier, and ship with confidence.

> [!NOTE]
> [Documentation](https://drexed.github.io/cmdx/getting_started/) reflects the latest code on `main`. For version-specific documentation, refer to the `docs/` directory within that version's tag.

## What you get

- **Standardized task contract** — typed inputs, declared outputs, explicit halts
- **Type system** — 13 coercers, 7 validators, all pluggable
- **Built-in flow control** — `skip!` / `fail!` / `throw!` with structured metadata
- **Retries and faults** — declarative `retry_on` with configurable jitter
- **Middleware and callbacks** — wrap the lifecycle without touching `work`
- **Observability** — structured logs and telemetry, no extra instrumentation
- **Composable workflows** — chain tasks into larger processes

See the [feature comparison](https://drexed.github.io/cmdx/comparison/) for how CMDx stacks up against other service-object gems.

## Requirements

- Ruby: MRI 3.3+ or a compatible JRuby/TruffleRuby release
- Runtime dependencies: `bigdecimal` and `logger` (stdlib only — no ActiveSupport required)

Rails support is built-in, but CMDx is framework-agnostic at its core.

## Installation

```sh
gem install cmdx
# - or -
bundle add cmdx
```

## Quick Example

CMDx organizes business logic around the **CERO** pattern (pronounced "zero"): **Compose**, **Execute**, **React**, **Observe**.

### 1. Compose

Declare inputs, outputs, retries, and callbacks, then implement `work`.

```ruby
class AnalyzeMetrics < CMDx::Task
  retry_on Net::ReadTimeout, limit: 3, jitter: :exponential

  on_success :track_analysis_completion!

  required :dataset_id, coerce: :integer, numeric: { min: 1 }

  optional :analysis_type, default: "standard"

  output :result, :analyzed_at

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

Every invocation returns a `Result`. Inputs are coerced and validated, exceptions are captured, outputs are verified, and the outcome is logged — automatically.

```ruby
result = AnalyzeMetrics.execute(
  dataset_id: 123,
  "analysis_type" => "advanced"
)
```

Use `execute!` instead when you want failures to raise a `Fault`.

### 3. React

Branch on the result's status and read values, reasons, or metadata from it.

```ruby
if result.success?
  puts "Metrics analyzed at #{result.context.analyzed_at}"
elsif result.skipped?
  puts "Skipped: #{result.reason}"
elsif result.failed?
  puts "Failed: #{result.reason} (code #{result.metadata[:code]})"
end
```

### 4. Observe

Every execution emits a structured log line with the chain id, task identity, state, status, reason, metadata, and duration — enough to correlate nested tasks and reconstruct what happened.

```log
I, [2026-04-19T18:42:37.000000Z #3784] INFO -- cmdx: cid="018c2b95-b764-7fff-a1d2-..." index=1 root=false type="Task" task=SendAnalyzedEmail id="018c2b95-c091-..." state="complete" status="success" reason=nil metadata={} duration=34.7 tags=[]

I, [2026-04-19T18:43:15.000000Z #3784] INFO -- cmdx: cid="018c2b95-b764-7fff-a1d2-..." index=0 root=true type="Task" task=AnalyzeMetrics id="018c2b95-b764-..." state="complete" status="success" reason=nil metadata={} duration=187.4 tags=[]
```

Ready to dive in? Check out the [Getting Started](https://drexed.github.io/cmdx/getting_started/) guide.

## Ecosystem

- [cmdx-i18n](https://github.com/drexed/cmdx-i18n) - 85+ translations
- [cmdx-rspec](https://github.com/drexed/cmdx-rspec) - RSpec test matchers

## Contributing

Bug reports and pull requests are welcome at <https://github.com/drexed/cmdx>. We're committed to fostering a welcoming, collaborative community. Please follow our [code of conduct](CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [LGPLv3 License](https://www.gnu.org/licenses/lgpl-3.0.html).
