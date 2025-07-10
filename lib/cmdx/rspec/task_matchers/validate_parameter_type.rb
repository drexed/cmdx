# frozen_string_literal: true

RSpec::Matchers.define :validate_parameter_type do |parameter_name, expected_type|
  match do |task_class|
    # Test with invalid type - use string when expecting integer, etc.
    invalid_value = case expected_type
                    when :integer then "not_an_integer"
                    when :string then 123
                    when :boolean then "not_a_boolean"
                    when :hash then "not_a_hash"
                    when :array then "not_an_array"
                    else "invalid_value"
                    end

    result = task_class.call(parameter_name => invalid_value)
    result.failed? &&
      result.metadata[:reason]&.include?("#{parameter_name} must be a #{expected_type}")
  end

  failure_message do |task_class|
    invalid_value = case expected_type
                    when :integer then "not_an_integer"
                    when :string then 123
                    when :boolean then "not_a_boolean"
                    when :hash then "not_a_hash"
                    when :array then "not_an_array"
                    else "invalid_value"
                    end

    result = task_class.call(parameter_name => invalid_value)
    if result.success?
      "expected task to fail type validation for parameter #{parameter_name} (#{expected_type}), but it succeeded"
    elsif result.failed?
      "expected task to fail with type validation message for #{parameter_name} (#{expected_type}), but failed with: #{result.metadata[:reason]}"
    else
      "expected task to fail type validation for parameter #{parameter_name} (#{expected_type}), but was #{result.status}"
    end
  end

  failure_message_when_negated do |_task_class|
    "expected task not to validate parameter type #{parameter_name} (#{expected_type}), but it did"
  end

  description do
    "validate parameter type #{parameter_name} (#{expected_type})"
  end
end
