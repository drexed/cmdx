# frozen_string_literal: true

# RSpec matcher for asserting that a task result has a good outcome.
#
# This matcher checks if a CMDx::Result object represents a successful completion,
# which includes both successful and skipped results. A result has a good outcome when
# its status is either "success" or "skipped" (i.e., anything other than "failed").
# This is useful for testing that tasks complete without errors, even if they were
# skipped due to conditions, as skipped tasks are still considered successful outcomes.
#
# @return [Boolean] true if the result has a good outcome (success or skipped)
#
# @example Testing successful task outcome
#   result = ProcessDataTask.call(data: "valid")
#   expect(result).to have_good_outcome
#
# @example Testing skipped task outcome (still good)
#   result = BackupTask.call(force: false)
#   expect(result).to have_good_outcome  # Skipped is still good
#
# @example Testing non-error completion paths
#   result = ConditionalTask.call(condition: false)
#   expect(result).to have_good_outcome  # Either success or skip is good
#
# @example Negative assertion for failed tasks
#   result = ValidationTask.call(data: "invalid")
#   expect(result).not_to have_good_outcome
#
# @example Distinguishing from bad outcomes
#   successful_result = CleanTask.call(data: "valid")
#   failed_result = BrokenTask.call(data: "invalid")
#   expect(successful_result).to have_good_outcome
#   expect(failed_result).to have_bad_outcome
#
# @example Testing workflow completion
#   workflow_result = ProcessingWorkflow.call(data: "test")
#   expect(workflow_result).to have_good_outcome.and be_complete
RSpec::Matchers.define :have_good_outcome do
  match(&:good?)

  failure_message do |result|
    "expected result to have good outcome (success or skipped), but was #{result.status}"
  end

  failure_message_when_negated do |result|
    "expected result not to have good outcome, but it did (status: #{result.status})"
  end

  description do
    "have good outcome"
  end
end
