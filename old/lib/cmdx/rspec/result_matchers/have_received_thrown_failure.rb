# frozen_string_literal: true

# RSpec matcher for asserting that a task result has received a thrown failure.
#
# This matcher checks if a CMDx::Result object represents a failure that was
# thrown from another task and received by this task. This is distinct from
# failures that were caused by the task itself or thrown by the task to others.
# A result has received a thrown failure when it's both failed and the failure
# was propagated from elsewhere in the chain, making this useful for testing
# error propagation and workflow failure handling.
#
# @return [Boolean] true if the result is failed and received a thrown failure
#
# @example Testing error propagation in workflows
#   workflow_result = ProcessingWorkflow.call(data: "invalid")
#   receiving_task = workflow_result.chain.find { |r| r.thrown_failure? }
#   expect(receiving_task).to have_received_thrown_failure
#
# @example Testing downstream task failure handling
#   result = CleanupTask.call(previous_task_failed: true)
#   expect(result).to have_received_thrown_failure
#
# @example Distinguishing failure types in chain
#   workflow_result = MultiStepWorkflow.call(data: "problematic")
#   original_failure = workflow_result.chain.find(&:caused_failure?)
#   received_failure = workflow_result.chain.find(&:thrown_failure?)
#   expect(original_failure).to have_caused_failure
#   expect(received_failure).to have_received_thrown_failure
#
# @example Testing error handling middleware
#   result = ErrorHandlingTask.call(upstream_error: error_obj)
#   expect(result).to have_received_thrown_failure
#
# @example Negative assertion for self-caused failures
#   result = ValidatingTask.call(data: "invalid")
#   expect(result).not_to have_received_thrown_failure
#
# @example Testing workflow interruption propagation
#   workflow_result = InterruptedWorkflow.call(data: "test")
#   interrupted_tasks = workflow_result.chain.select(&:thrown_failure?)
#   interrupted_tasks.each do |task|
#     expect(task).to have_received_thrown_failure
#   end
RSpec::Matchers.define :have_received_thrown_failure do
  match do |result|
    result.failed? && result.thrown_failure?
  end

  failure_message do |result|
    if result.failed?
      "expected result to have received thrown failure, but it #{result.caused_failure? ? 'caused' : 'threw'} failure instead"
    else
      "expected result to have received thrown failure, but it was not failed (status: #{result.status})"
    end
  end

  failure_message_when_negated do |_result|
    "expected result not to have received thrown failure, but it did"
  end

  description do
    "have received thrown failure"
  end
end
