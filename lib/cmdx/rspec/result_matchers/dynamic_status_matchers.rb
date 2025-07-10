# frozen_string_literal: true

CMDx::Result::STATUSES.each do |status|
  RSpec::Matchers.define :"be_#{status}" do
    match do |result|
      result.public_send(:"#{status}?")
    end

    failure_message do |result|
      "expected result to be #{status}, but was #{result.status}"
    end

    failure_message_when_negated do |_result|
      "expected result not to be #{status}, but it was"
    end

    description do
      "be #{status}"
    end
  end
end
