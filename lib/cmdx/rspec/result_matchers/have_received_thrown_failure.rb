# frozen_string_literal: true

RSpec::Matchers.define :have_received_thrown_failure do
  match do |result|
    result.failed? && result.thrown_failure?
  end

  failure_message do |result|
    if result.failed?
      "expected result to have received thrown failure, but it #{result.caused_failure? ? 'caused' : 'threw'} failure instead"
    else
      "expected result to have received thrown failure, but it was not failed (status: #{result.status})"
    end
  end

  failure_message_when_negated do |_result|
    "expected result not to have received thrown failure, but it did"
  end

  description do
    "have received thrown failure"
  end
end
