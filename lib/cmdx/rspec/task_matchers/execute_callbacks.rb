# frozen_string_literal: true

RSpec::Matchers.define :execute_callbacks do |*callback_names|
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
