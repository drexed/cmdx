# frozen_string_literal: true

# RSpec matcher for asserting that a task result has thrown a failure.
#
# This matcher checks if a CMDx::Result object represents a failure that was
# thrown to another task. This is distinct from failures that were caused by
# the task itself or received from other tasks. A result has thrown a failure
# when it's both failed and actively passed the failure to another task in
# the chain. Optionally verifies that the thrown failure came from a specific
# original result, useful for testing complex failure propagation scenarios.
#
# @param expected_original_result [CMDx::Result, nil] optional original result that was thrown
#
# @return [Boolean] true if the result is failed, threw a failure, and optionally matches expected original
#
# @example Testing basic failure throwing
#   workflow_result = ProcessingWorkflow.call(data: "invalid")
#   throwing_task = workflow_result.chain.find(&:threw_failure?)
#   expect(throwing_task).to have_thrown_failure
#
# @example Testing failure propagation with specific original
#   workflow_result = MultiStepWorkflow.call(data: "problematic")
#   original_failure = workflow_result.chain.find(&:caused_failure?)
#   throwing_task = workflow_result.chain.find(&:threw_failure?)
#   expect(throwing_task).to have_thrown_failure(original_failure)
#
# @example Testing middleware failure handling
#   result = ErrorHandlingMiddleware.call(upstream_failure: failure_obj)
#   expect(result).to have_thrown_failure
#
# @example Distinguishing failure types in chain
#   workflow_result = FailingWorkflow.call(data: "invalid")
#   caused_task = workflow_result.chain.find(&:caused_failure?)
#   threw_task = workflow_result.chain.find(&:threw_failure?)
#   received_task = workflow_result.chain.find(&:thrown_failure?)
#   expect(caused_task).to have_caused_failure
#   expect(threw_task).to have_thrown_failure
#   expect(received_task).to have_received_thrown_failure
#
# @example Negative assertion for self-caused failures
#   result = ValidatingTask.call(data: "invalid")
#   expect(result).not_to have_thrown_failure
#
# @example Testing workflow interruption propagation
#   workflow_result = InterruptedWorkflow.call(data: "test")
#   propagating_tasks = workflow_result.chain.select(&:threw_failure?)
#   propagating_tasks.each do |task|
#     expect(task).to have_thrown_failure
#   end
#
# @since 1.0.0
RSpec::Matchers.define :have_thrown_failure do |expected_original_result = nil|
  match do |result|
    result.failed? &&
      result.threw_failure? &&
      (expected_original_result.nil? || result.threw_failure == expected_original_result)
  end

  failure_message do |result|
    messages = []
    messages << "expected result to be failed, but was #{result.status}" unless result.failed?
    messages << "expected result to have thrown failure, but it #{result.caused_failure? ? 'caused' : 'received'} failure instead" unless result.threw_failure?

    messages << "expected to throw failure from #{expected_original_result}, but threw from #{result.threw_failure}" if expected_original_result && result.threw_failure != expected_original_result

    messages.join(", ")
  end

  failure_message_when_negated do |_result|
    "expected result not to have thrown failure, but it did"
  end

  description do
    desc = "have thrown failure"
    desc += " from #{expected_original_result}" if expected_original_result
    desc
  end
end
