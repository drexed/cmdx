# frozen_string_literal: true

# RSpec matcher for asserting that a task result has completed successfully.
#
# This matcher checks if a CMDx::Result object represents a fully successful task
# execution, which means the task completed without errors and reached the end of
# its lifecycle. A result is considered a successful task when it has "success" status,
# "complete" state, and has been executed. Optionally validates expected context values.
#
# @param expected_context [Hash] optional hash of expected context key-value pairs
#
# @return [Boolean] true if the result is successful, complete, executed, and matches expected context
#
# @example Basic usage with successful task
#   result = ProcessOrderTask.call(order_id: 123)
#   expect(result).to be_successful_task
#
# @example Checking successful task with context validation
#   result = CalculateTotalTask.call(items: [item1, item2])
#   expect(result).to be_successful_task(total: 150.00, tax: 12.50)
#
# @example Validating multiple context attributes
#   result = UserRegistrationTask.call(email: "user@example.com")
#   expect(result).to be_successful_task(
#     user_id: 42,
#     email_sent: true,
#     activation_token: be_present
#   )
#
# @example Negative assertion
#   result = FailedValidationTask.call(data: "invalid")
#   expect(result).not_to be_successful_task
#
# @example Combining with other matchers
#   result = ProcessPaymentTask.call(amount: 100)
#   expect(result).to be_successful_task.and have_runtime
#
# @example Testing context without specific values
#   result = DataProcessingTask.call(data: dataset)
#   expect(result).to be_successful_task({})  # Just check success without context
#
# @since 1.0.0
RSpec::Matchers.define :be_successful_task do |expected_context = {}|
  match do |result|
    result.success? &&
      result.complete? &&
      result.executed? &&
      (expected_context.empty? || context_matches?(result, expected_context))
  end

  failure_message do |result|
    messages = []
    messages << "expected result to be successful, but was #{result.status}" unless result.success?
    messages << "expected result to be complete, but was #{result.state}" unless result.complete?
    messages << "expected result to be executed, but was not" unless result.executed?

    unless expected_context.empty?
      mismatches = context_mismatches(result, expected_context)
      messages << "expected context to match #{expected_context}, but #{mismatches}" if mismatches.any?
    end

    messages.join(", ")
  end

  failure_message_when_negated do |_result|
    "expected result not to be successful, but it was"
  end

  description do
    desc = "be a successful task"
    desc += " with context #{expected_context}" unless expected_context.empty?
    desc
  end

  private

  def context_matches?(result, expected_context)
    expected_context.all? do |key, value|
      result.context.public_send(key) == value
    end
  end

  def context_mismatches(result, expected_context)
    expected_context.filter_map do |key, expected_value|
      actual_value = result.context.public_send(key)
      "#{key}: expected #{expected_value}, got #{actual_value}" if actual_value != expected_value
    end
  end
end
