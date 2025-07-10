# frozen_string_literal: true

RSpec::Matchers.define :have_context do |expected_effects|
  match do |result|
    expected_effects.all? do |key, expected_value|
      actual_value = result.context.public_send(key)
      if expected_value.respond_to?(:matches?)
        expected_value.matches?(actual_value)
      else
        actual_value == expected_value
      end
    end
  end

  failure_message do |result|
    mismatches = expected_effects.filter_map do |key, expected_value|
      actual_value = result.context.public_send(key)
      match_result = if expected_value.respond_to?(:matches?)
                       expected_value.matches?(actual_value)
                     else
                       actual_value == expected_value
                     end

      "#{key}: expected #{expected_value}, got #{actual_value}" unless match_result
    end
    "expected context to have side effects #{expected_effects}, but #{mismatches.join(', ')}"
  end

  failure_message_when_negated do |_result|
    "expected context not to have side effects #{expected_effects}, but it did"
  end

  description do
    "have side effects #{expected_effects}"
  end
end
