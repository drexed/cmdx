# frozen_string_literal: true

RSpec::Matchers.define :have_been_skipped do |**data|
  description { "have been skipped" }

  match(notify_expectation_failures: true) do |result|
    raise ArgumentError, "must be a Result" unless result.is_a?(CMDx::Result)

    expect(result.to_h).to include(
      state: CMDx::Result::INTERRUPTED,
      status: CMDx::Result::SKIPPED,
      outcome: CMDx::Result::SKIPPED,
      metadata: {},
      reason: CMDx::Locale.t("cmdx.faults.unspecified"),
      cause: nil,
      **data
    )
  end
end
