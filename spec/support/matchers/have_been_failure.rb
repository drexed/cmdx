# frozen_string_literal: true

RSpec::Matchers.define :have_been_failure do |**data|
  description { "have been a failure" }

  match(notify_expectation_failures: true) do |result|
    raise ArgumentError, "must be a CMDx::Result" unless result.is_a?(CMDx::Result)

    expect(result.to_h).to include(
      state: CMDx::Result::INTERRUPTED,
      status: CMDx::Result::FAILED,
      outcome: CMDx::Result::FAILED,
      metadata: {},
      reason: CMDx::Locale.t("cmdx.faults.unspecified"),
      cause: be_a(CMDx::FailFault),
      **data
    )
  end
end
