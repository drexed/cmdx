# frozen_string_literal: true

# RSpec matchers for asserting task result statuses.
#
# This file dynamically generates RSpec matchers for each execution status defined
# in CMDx::Result::STATUSES. These matchers check the outcome of task logic execution,
# which represents what happened when the task's business logic ran (success, skip, or failure).
#
# The following matchers are automatically generated:
# - `be_success` - Task completed successfully without errors
# - `be_skipped` - Task was intentionally skipped due to conditions
# - `be_failed` - Task failed due to errors or validation issues
#
# @return [Boolean] true if the result matches the expected status
#
# @example Testing success status
#   result = ProcessDataTask.call(data: "valid")
#   expect(result).to be_success
#
# @example Testing skipped status
#   result = SendEmailTask.call(user: inactive_user)
#   expect(result).to be_skipped
#
# @example Testing failed status
#   result = ValidateUserTask.call(user_id: nil)
#   expect(result).to be_failed
#
# @example Negative assertion
#   result = SuccessfulTask.call(data: "valid")
#   expect(result).not_to be_failed
#
# @example Using with state matchers
#   result = ProcessPaymentTask.call(amount: -100)
#   expect(result).to be_failed.and be_interrupted
#
# @example Testing good vs bad outcomes
#   result = BackupTask.call(force: false)
#   expect(result).to be_skipped  # Skipped is still a "good" outcome
#
# @since 1.0.0
CMDx::Result::STATUSES.each do |status|
  RSpec::Matchers.define :"be_#{status}" do
    match do |result|
      result.public_send(:"#{status}?")
    end

    failure_message do |result|
      "expected result to be #{status}, but was #{result.status}"
    end

    failure_message_when_negated do |_result|
      "expected result not to be #{status}, but it was"
    end

    description do
      "be #{status}"
    end
  end
end
