# frozen_string_literal: true

# RSpec matcher for asserting that a task result has failed with specific conditions.
#
# This matcher checks if a CMDx::Result object is in a failed state, which means
# the task was executed but encountered an error or failure condition. A result
# is considered failed when it's in both "failed" status and "interrupted" state,
# and has been executed. Optionally checks for specific failure reasons and metadata.
#
# @param expected_reason [String, Symbol, nil] optional expected failure reason
#
# @return [Boolean] true if the result is failed, interrupted, executed, and matches expected criteria
#
# @example Basic usage with failed task
#   result = ValidateUserTask.call(user_id: nil)
#   expect(result).to be_failed_task
#
# @example Checking for specific failure reason
#   result = ProcessPaymentTask.call(amount: -100)
#   expect(result).to be_failed_task("invalid_amount")
#
# @example Using with_reason chain
#   result = AuthenticateUserTask.call(token: "invalid")
#   expect(result).to be_failed_task.with_reason(:authentication_failed)
#
# @example Checking failure with metadata
#   result = UploadFileTask.call(file: corrupted_file)
#   expect(result).to be_failed_task.with_metadata(file_size: 0, error_code: "CORRUPTED")
#
# @example Combining reason and metadata checks
#   result = ValidateDataTask.call(data: invalid_data)
#   expect(result).to be_failed_task("validation_error").with_metadata(field: "email", rule: "format")
#
# @example Negative assertion
#   result = SuccessfulTask.call(data: "valid")
#   expect(result).not_to be_failed_task
RSpec::Matchers.define :be_failed_task do |expected_reason = nil|
  match do |result|
    result.failed? &&
      result.interrupted? &&
      result.executed? &&
      (expected_reason.nil? || result.metadata[:reason] == expected_reason)
  end

  chain :with_reason do |reason|
    @expected_reason = reason
  end

  chain :with_metadata do |metadata|
    @expected_metadata = metadata
  end

  match do |result|
    reason = @expected_reason || expected_reason
    metadata = @expected_metadata || {}

    result.failed? &&
      result.interrupted? &&
      result.executed? &&
      (reason.nil? || result.metadata[:reason] == reason) &&
      (metadata.empty? || metadata.all? { |k, v| result.metadata[k] == v })
  end

  failure_message do |result|
    messages = []
    messages << "expected result to be failed, but was #{result.status}" unless result.failed?
    messages << "expected result to be interrupted, but was #{result.state}" unless result.interrupted?
    messages << "expected result to be executed, but was not" unless result.executed?

    reason = @expected_reason || expected_reason
    messages << "expected failure reason to be '#{reason}', but was '#{result.metadata[:reason]}'" if reason && result.metadata[:reason] != reason

    if @expected_metadata&.any?
      mismatches = @expected_metadata.filter_map do |k, v|
        "#{k}: expected #{v}, got #{result.metadata[k]}" if result.metadata[k] != v
      end
      messages.concat(mismatches)
    end

    messages.join(", ")
  end

  failure_message_when_negated do |_result|
    "expected result not to be failed, but it was"
  end

  description do
    desc = "be a failed task"
    reason = @expected_reason || expected_reason
    desc += " with reason '#{reason}'" if reason
    desc += " with metadata #{@expected_metadata}" if @expected_metadata&.any?
    desc
  end
end
