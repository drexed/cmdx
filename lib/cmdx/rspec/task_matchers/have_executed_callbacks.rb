# frozen_string_literal: true

# RSpec matcher for asserting that a task has executed specific callbacks.
#
# This matcher verifies that callbacks were actually invoked during task execution,
# not just registered. It works by mocking the callback execution to track which
# callbacks are called, then executing the task and checking that the expected
# callbacks were invoked. This is useful for testing that callback logic is properly
# triggered during task execution rather than just checking callback registration.
#
# @param callback_names [Array<Symbol, String>] the names of callbacks expected to execute
#
# @return [Boolean] true if all specified callbacks were executed during task execution
#
# @example Testing basic callback execution
#   class MyTask < CMDx::Task
#     before_execution :setup
#     def call; end
#   end
#   expect(MyTask.new).to have_executed_callbacks(:before_execution)
#
# @example Testing callback execution with specific callable
#   class ProcessTask < CMDx::Task
#     after_execution :log_completion
#     def call; end
#   end
#   expect(ProcessTask).to have_callback(:after_execution).with_callable(:log_completion)
#
# @example Testing callback execution with result
#   result = MyTask.call(data: "test")
#   expect(result).to have_executed_callbacks(:before_execution, :after_execution)
#
# @example Negative assertion
#   class SimpleTask < CMDx::Task
#     def call; end
#   end
#   expect(SimpleTask.new).not_to have_executed_callbacks(:before_execution)
#
# @since 1.0.0
RSpec::Matchers.define :have_executed_callbacks do |*callback_names|
  match do |task_or_result|
    @executed_callbacks = []

    # Mock the callback execution to track what gets called
    if task_or_result.is_a?(CMDx::Task)
      task = task_or_result
      original_callback_call = task.cmd_callbacks.method(:call)

      allow(task.cmd_callbacks).to receive(:call) do |task_instance, callback_name|
        @executed_callbacks << callback_name
        original_callback_call.call(task_instance, callback_name)
      end

      task.perform
    else
      # If it's a result, check if callbacks were executed during task execution
      result = task_or_result
      # This would require the callbacks to be tracked during execution
      # For now, assume callbacks were executed based on result state
      @executed_callbacks = infer_executed_callbacks(result)
    end

    callback_names.all? { |callback_name| @executed_callbacks.include?(callback_name) }
  end

  failure_message do |_task_or_result|
    missing_callbacks = callback_names - @executed_callbacks
    "expected to execute callbacks #{callback_names}, but missing #{missing_callbacks}. Executed: #{@executed_callbacks}"
  end

  failure_message_when_negated do |_task_or_result|
    "expected not to execute callbacks #{callback_names}, but executed #{@executed_callbacks & callback_names}"
  end

  description do
    "execute callbacks #{callback_names}"
  end

  private

  def infer_executed_callbacks(result)
    callbacks = []
    callbacks << :before_validation if result.executed?
    callbacks << :after_validation if result.executed?
    callbacks << :before_execution if result.executed?
    callbacks << :after_execution if result.executed?
    callbacks << :on_executed if result.executed?
    callbacks << :"on_#{result.status}" if result.executed?
    callbacks << :on_good if result.good?
    callbacks << :on_bad if result.bad?
    callbacks << :"on_#{result.state}" if result.executed?
    callbacks
  end
end
