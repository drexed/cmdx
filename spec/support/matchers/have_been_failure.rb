# frozen_string_literal: true

RSpec::Matchers.define :have_been_failure do |**data|
  description { "have been failure" }

  # chain :with_context do |context|
  #   @host = host
  # end

  match(notify_expectation_failures: true) do |result|
    raise ArgumentError, "must be a Result" unless result.is_a?(CMDx::Result)

    expect(result.to_h).to include(
      state: CMDx::Result::INTERRUPTED,
      status: CMDx::Result::FAILED,
      outcome: CMDx::Result::FAILED,
      metadata: {},
      reason: CMDx::Locale.t("cmdx.faults.unspecified"),
      cause: nil,
      **data
    )
  end
end
