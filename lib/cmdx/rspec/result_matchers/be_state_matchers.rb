# frozen_string_literal: true

# RSpec matchers for asserting task result states.
#
# This file dynamically generates RSpec matchers for each execution state defined
# in CMDx::Result::STATES. These matchers check the current execution state of a
# task result, which represents where the task is in its lifecycle from
# initialization through completion or interruption.
#
# The following matchers are automatically generated:
# - `be_initialized` - Task has been created but not yet started
# - `be_executing` - Task is currently running its logic
# - `be_complete` - Task has successfully finished execution
# - `be_interrupted` - Task execution was halted due to failure or skip
#
# @return [Boolean] true if the result matches the expected state
#
# @example Testing initialized state
#   result = MyTask.new.result
#   expect(result).to be_initialized
#
# @example Testing executing state
#   result = MyTask.call(data: "processing")
#   expect(result).to be_executing  # During execution
#
# @example Testing complete state
#   result = SuccessfulTask.call(data: "valid")
#   expect(result).to be_complete
#
# @example Testing interrupted state
#   result = FailedTask.call(data: "invalid")
#   expect(result).to be_interrupted
#
# @example Negative assertion
#   result = SuccessfulTask.call(data: "valid")
#   expect(result).not_to be_initialized
#
# @example Using with other matchers
#   result = ProcessDataTask.call(data: invalid_data)
#   expect(result).to be_interrupted.and be_failed
#
# @since 1.0.0
CMDx::Result::STATES.each do |state|
  RSpec::Matchers.define :"be_#{state}" do
    match do |result|
      result.public_send(:"#{state}?")
    end

    failure_message do |result|
      "expected result to be #{state}, but was #{result.state}"
    end

    failure_message_when_negated do |_result|
      "expected result not to be #{state}, but it was"
    end

    description do
      "be #{state}"
    end
  end
end
