# frozen_string_literal: true

# RSpec matcher for asserting that a task result has a specific chain index.
#
# This matcher checks if a CMDx::Result object is positioned at the expected index
# within its execution chain. The chain index represents the zero-based position of
# the task in the workflow execution order, which is useful for testing workflow
# structure, execution order, and identifying specific tasks within complex chains.
#
# @param expected_index [Integer] the expected zero-based index position in the chain
#
# @return [Boolean] true if the result's chain index matches the expected index
#
# @example Testing first task in workflow
#   workflow_result = MyWorkflow.call(data: "test")
#   first_task = workflow_result.chain.first
#   expect(first_task).to have_chain_index(0)
#
# @example Testing specific task position
#   workflow_result = ProcessingWorkflow.call(items: [1, 2, 3])
#   validation_task = workflow_result.chain[2]
#   expect(validation_task).to have_chain_index(2)
#
# @example Testing failed task position
#   workflow_result = FailingWorkflow.call(data: "invalid")
#   failed_task = workflow_result.chain.find(&:failed?)
#   expect(failed_task).to have_chain_index(1)
#
# @example Testing last task in chain
#   workflow_result = CompletedWorkflow.call(data: "valid")
#   last_task = workflow_result.chain.last
#   expect(last_task).to have_chain_index(workflow_result.chain.length - 1)
#
# @example Negative assertion
#   workflow_result = MyWorkflow.call(data: "test")
#   middle_task = workflow_result.chain[1]
#   expect(middle_task).not_to have_chain_index(0)
#
# @example Testing workflow interruption point
#   workflow_result = InterruptedWorkflow.call(data: "invalid")
#   interrupting_task = workflow_result.chain.find(&:interrupted?)
#   expect(interrupting_task).to have_chain_index(3)
#
# @since 1.0.0
RSpec::Matchers.define :have_chain_index do |expected_index|
  match do |result|
    result.index == expected_index
  end

  failure_message do |result|
    "expected result to have chain index #{expected_index}, but was #{result.index}"
  end

  failure_message_when_negated do |_result|
    "expected result not to have chain index #{expected_index}, but it did"
  end

  description do
    "have chain index #{expected_index}"
  end
end
