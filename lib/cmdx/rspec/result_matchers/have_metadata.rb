# frozen_string_literal: true

RSpec::Matchers.define :have_metadata do |expected_metadata = {}|
  match do |result|
    expected_metadata.all? do |key, value|
      actual_value = result.metadata[key]
      if value.respond_to?(:matches?)
        value.matches?(actual_value)
      else
        actual_value == value
      end
    end
  end

  chain :including do |metadata|
    @additional_metadata = metadata
  end

  match do |result|
    all_metadata = expected_metadata.merge(@additional_metadata || {})
    all_metadata.all? do |key, value|
      actual_value = result.metadata[key]
      if value.respond_to?(:matches?)
        value.matches?(actual_value)
      else
        actual_value == value
      end
    end
  end

  failure_message do |result|
    all_metadata = expected_metadata.merge(@additional_metadata || {})
    mismatches = all_metadata.filter_map do |key, expected_value|
      actual_value = result.metadata[key]
      match_result = if expected_value.respond_to?(:matches?)
                       expected_value.matches?(actual_value)
                     else
                       actual_value == expected_value
                     end
      "#{key}: expected #{expected_value}, got #{actual_value}" unless match_result
    end
    "expected metadata to include #{all_metadata}, but #{mismatches.join(', ')}"
  end

  failure_message_when_negated do |_result|
    all_metadata = expected_metadata.merge(@additional_metadata || {})
    "expected metadata not to include #{all_metadata}, but it did"
  end

  description do
    all_metadata = expected_metadata.merge(@additional_metadata || {})
    "have metadata #{all_metadata}"
  end
end
