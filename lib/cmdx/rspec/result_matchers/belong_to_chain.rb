# frozen_string_literal: true

RSpec::Matchers.define :belong_to_chain do |expected_chain = nil|
  match do |result|
    result.chain.is_a?(CMDx::Chain) &&
      (expected_chain.nil? || result.chain == expected_chain)
  end

  failure_message do |result|
    if result.chain.is_a?(CMDx::Chain)
      "expected result to belong to chain #{expected_chain}, but belonged to #{result.chain}"
    else
      "expected result to belong to a chain, but chain was #{result.chain.class}"
    end
  end

  failure_message_when_negated do |_result|
    if expected_chain
      "expected result not to belong to chain #{expected_chain}, but it did"
    else
      "expected result not to belong to a chain, but it did"
    end
  end

  description do
    desc = "belong to chain"
    desc += " #{expected_chain}" if expected_chain
    desc
  end
end
