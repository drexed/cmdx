# frozen_string_literal: true

# RSpec matcher for asserting that a task result has a bad outcome.
#
# This matcher checks if a CMDx::Result object represents a non-successful outcome,
# which includes both failed and skipped results. A result has a bad outcome when
# its status is anything other than "success" (i.e., either "failed" or "skipped").
# This is useful for testing error handling and conditional logic paths.
#
# @return [Boolean] true if the result has a bad outcome (failed or skipped)
#
# @example Testing failed task outcome
#   result = ValidateDataTask.call(data: "invalid")
#   expect(result).to have_bad_outcome
#
# @example Testing skipped task outcome
#   result = ProcessQueueTask.call(queue: empty_queue)
#   expect(result).to have_bad_outcome
#
# @example Testing error handling paths
#   result = ProcessPaymentTask.call(amount: -100)
#   expect(result).to have_bad_outcome.and be_failed
#
# @example Negative assertion for successful tasks
#   result = SuccessfulTask.call(data: "valid")
#   expect(result).not_to have_bad_outcome
#
# @example Using in conditional test logic
#   result = ConditionalTask.call(condition: false)
#   if result.bad?
#     expect(result).to have_bad_outcome
#   end
#
# @example Opposite of good outcome
#   result = SkippedTask.call(reason: "not_needed")
#   expect(result).to have_bad_outcome.and not_to have_good_outcome
#
# @since 1.0.0
RSpec::Matchers.define :have_bad_outcome do
  match(&:bad?)

  failure_message do |result|
    "expected result to have bad outcome (not success), but was #{result.status}"
  end

  failure_message_when_negated do |result|
    "expected result not to have bad outcome, but it did (status: #{result.status})"
  end

  description do
    "have bad outcome"
  end
end
