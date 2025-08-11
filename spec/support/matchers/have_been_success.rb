# frozen_string_literal: true

RSpec::Matchers.define :have_been_success do |**data|
  description { "have been a success" }

  match(notify_expectation_failures: true) do |result|
    raise ArgumentError, "must be a CMDx::Result" unless result.is_a?(CMDx::Result)

    expect(result.to_h).to include(
      state: CMDx::Result::COMPLETE,
      status: CMDx::Result::SUCCESS,
      outcome: CMDx::Result::SUCCESS,
      metadata: {},
      **data
    )
  end
end
