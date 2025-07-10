# frozen_string_literal: true

RSpec::Matchers.define :have_chain_index do |expected_index|
  match do |result|
    result.index == expected_index
  end

  failure_message do |result|
    "expected result to have chain index #{expected_index}, but was #{result.index}"
  end

  failure_message_when_negated do |_result|
    "expected result not to have chain index #{expected_index}, but it did"
  end

  description do
    "have chain index #{expected_index}"
  end
end
