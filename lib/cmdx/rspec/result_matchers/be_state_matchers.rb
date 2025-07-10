# frozen_string_literal: true

CMDx::Result::STATES.each do |state|
  RSpec::Matchers.define :"be_#{state}" do
    match do |result|
      result.public_send(:"#{state}?")
    end

    failure_message do |result|
      "expected result to be #{state}, but was #{result.state}"
    end

    failure_message_when_negated do |_result|
      "expected result not to be #{state}, but it was"
    end

    description do
      "be #{state}"
    end
  end
end
