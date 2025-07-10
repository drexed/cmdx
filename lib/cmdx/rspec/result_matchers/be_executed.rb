# frozen_string_literal: true

RSpec::Matchers.define :be_executed do
  match(&:executed?)

  failure_message do |result|
    "expected result to be executed, but was in #{result.state} state"
  end

  failure_message_when_negated do |result|
    "expected result not to be executed, but it was (state: #{result.state})"
  end

  description do
    "be executed"
  end
end
