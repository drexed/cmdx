# frozen_string_literal: true

# RSpec matcher for asserting that a task result has preserved specific context values.
#
# This matcher checks if a CMDx::Result object's context contains values that were
# preserved from the original input or previous task execution. Unlike `have_context`
# which tests for side effects and new values, this matcher specifically verifies
# that certain context attributes retained their expected values throughout task
# execution, ensuring data integrity and proper context passing between tasks.
#
# @param preserved_attributes [Hash] hash of expected preserved context key-value pairs
#
# @return [Boolean] true if the context has preserved all expected attributes
#
# @example Testing basic context preservation
#   result = ProcessDataTask.call(user_id: 123, data: "input")
#   expect(result).to have_preserved_context(user_id: 123, data: "input")
#
# @example Testing workflow context preservation
#   workflow_result = UserWorkflow.call(user_id: 456, email: "user@example.com")
#   expect(workflow_result).to have_preserved_context(
#     user_id: 456,
#     email: "user@example.com"
#   )
#
# @example Testing preservation through multiple tasks
#   result = MultiStepTask.call(original_data: "important", temp_data: "process")
#   expect(result).to have_preserved_context(original_data: "important")
#
# @example Testing that critical data survives failures
#   result = FailingTask.call(user_id: 789, critical_flag: true)
#   expect(result).to have_preserved_context(
#     user_id: 789,
#     critical_flag: true
#   )
#
# @example Negative assertion for modified context
#   result = TransformTask.call(data: "original")
#   expect(result).not_to have_preserved_context(data: "original")
#
# @example Testing partial preservation
#   result = SelectiveTask.call(keep_this: "value", change_this: "old")
#   expect(result).to have_preserved_context(keep_this: "value")
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
