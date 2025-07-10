# frozen_string_literal: true

RSpec::Matchers.define :have_thrown_failure do |expected_original_result = nil|
  match do |result|
    result.failed? &&
      result.threw_failure? &&
      (expected_original_result.nil? || result.threw_failure == expected_original_result)
  end

  failure_message do |result|
    messages = []
    messages << "expected result to be failed, but was #{result.status}" unless result.failed?
    messages << "expected result to have thrown failure, but it #{result.caused_failure? ? 'caused' : 'received'} failure instead" unless result.threw_failure?

    messages << "expected to throw failure from #{expected_original_result}, but threw from #{result.threw_failure}" if expected_original_result && result.threw_failure != expected_original_result

    messages.join(", ")
  end

  failure_message_when_negated do |_result|
    "expected result not to have thrown failure, but it did"
  end

  description do
    desc = "have thrown failure"
    desc += " from #{expected_original_result}" if expected_original_result
    desc
  end
end
