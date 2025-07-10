# frozen_string_literal: true

RSpec::Matchers.define :have_good_outcome do
  match(&:good?)

  failure_message do |result|
    "expected result to have good outcome (success or skipped), but was #{result.status}"
  end

  failure_message_when_negated do |result|
    "expected result not to have good outcome, but it did (status: #{result.status})"
  end

  description do
    "have good outcome"
  end
end
