# frozen_string_literal: true

RSpec::Matchers.define :have_empty_metadata do
  match do |result|
    result.metadata.empty?
  end

  failure_message do |result|
    "expected metadata to be empty, but was #{result.metadata}"
  end

  failure_message_when_negated do |_result|
    "expected metadata not to be empty, but it was"
  end

  description do
    "have empty metadata"
  end
end
