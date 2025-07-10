# frozen_string_literal: true

RSpec::Matchers.define :have_caused_failure do
  match do |result|
    result.failed? && result.caused_failure?
  end

  failure_message do |result|
    if result.failed?
      "expected result to have caused failure, but it threw/received a failure instead"
    else
      "expected result to have caused failure, but it was not failed (status: #{result.status})"
    end
  end

  failure_message_when_negated do |_result|
    "expected result not to have caused failure, but it did"
  end

  description do
    "have caused failure"
  end
end
