# frozen_string_literal: true

# RSpec matcher for asserting that a task result has been executed.
#
# This matcher checks if a CMDx::Result object is in an executed state,
# which occurs when the task has finished execution regardless of whether
# it succeeded, failed, or was skipped. A result is considered executed
# when it's in either "complete" or "interrupted" state.
#
# @return [Boolean] true if the result is executed (complete or interrupted)
#
# @example Basic usage with successful task
#   result = MyTask.call(user_id: 123)
#   expect(result).to be_executed
#
# @example Usage with failed task
#   result = FailingTask.call
#   expect(result).to be_executed
#
# @example Negative assertion
#   task = MyTask.new
#   expect(task.result).not_to be_executed
#
# @example In workflow integration tests
#   result = MyWorkflow.call(data: "test")
#   expect(result).to be_executed
#   expect(result.context.processed).to be(true)
#
# @since 1.0.0
RSpec::Matchers.define :be_executed do
  match(&:executed?)

  failure_message do |result|
    "expected result to be executed, but was in #{result.state} state"
  end

  failure_message_when_negated do |result|
    "expected result not to be executed, but it was (state: #{result.state})"
  end

  description do
    "be executed"
  end
end
