# frozen_string_literal: true

RSpec::Matchers.define :have_bad_outcome do
  match(&:bad?)

  failure_message do |result|
    "expected result to have bad outcome (not success), but was #{result.status}"
  end

  failure_message_when_negated do |result|
    "expected result not to have bad outcome, but it did (status: #{result.status})"
  end

  description do
    "have bad outcome"
  end
end
