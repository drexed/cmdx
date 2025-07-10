# frozen_string_literal: true

RSpec::Matchers.define :have_preserved_context do |preserved_attributes|
  match do |result|
    preserved_attributes.all? do |key, expected_value|
      result.context.public_send(key) == expected_value
    end
  end

  failure_message do |result|
    mismatches = preserved_attributes.filter_map do |key, expected_value|
      actual_value = result.context.public_send(key)
      "#{key}: expected #{expected_value}, got #{actual_value}" if actual_value != expected_value
    end
    "expected context to preserve #{preserved_attributes}, but #{mismatches.join(', ')}"
  end

  failure_message_when_negated do |_result|
    "expected context not to preserve #{preserved_attributes}, but it did"
  end

  description do
    "preserve context #{preserved_attributes}"
  end
end
