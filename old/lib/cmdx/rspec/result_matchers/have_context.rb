# frozen_string_literal: true

# RSpec matcher for asserting that a task result has specific context side effects.
#
# This matcher checks if a CMDx::Result object's context contains expected values
# or side effects that were set during task execution. Tasks often modify the context
# to store computed values, intermediate results, or other data that needs to be
# passed between tasks in a workflow. This matcher supports both direct value
# comparisons and RSpec matchers for flexible assertions.
#
# @param expected_effects [Hash] hash of expected context key-value pairs or matchers
#
# @return [Boolean] true if the context has all expected side effects
#
# @example Testing simple context values
#   result = CalculateTask.call(a: 10, b: 20)
#   expect(result).to have_context(sum: 30, product: 200)
#
# @example Using RSpec matchers for flexible assertions
#   result = ProcessUserTask.call(user_id: 123)
#   expect(result).to have_context(
#     user: be_a(User),
#     created_at: be_a(Time),
#     email: match(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
#   )
#
# @example Testing computed values
#   result = AnalyzeDataTask.call(data: dataset)
#   expect(result).to have_context(
#     average: be_within(0.1).of(15.5),
#     count: be > 100,
#     processed: be_truthy
#   )
#
# @example Testing workflow context passing
#   workflow_result = DataProcessingWorkflow.call(input: "raw_data")
#   expect(workflow_result).to have_context(
#     raw_data: "raw_data",
#     processed_data: be_present,
#     validation_errors: be_empty
#   )
#
# @example Negative assertion
#   result = SimpleTask.call(data: "test")
#   expect(result).not_to have_context(unexpected_key: "value")
#
# @example Testing side effects in failed tasks
#   result = ValidateTask.call(data: "invalid")
#   expect(result).to have_context(
#     validation_errors: include("Data is invalid"),
#     attempted_at: be_a(Time)
#   )
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
