# frozen_string_literal: true

# RSpec matcher for asserting that a task class has a specific callback.
#
# This matcher checks if a CMDx::Task class has registered a callback with the
# specified name. Callbacks are methods that execute before, after, or around
# the main task logic. The matcher can optionally verify that the callback has
# a specific callable (method name, proc, or lambda) using the `with_callable`
# chain method for more precise callback validation.
#
# @param callback_name [Symbol, String] the name of the callback to check for
#
# @return [Boolean] true if the task has the specified callback and optionally the expected callable
#
# @example Testing basic callback presence
#   class MyTask < CMDx::Task
#     before_execution :validate_input
#     def call; end
#   end
#   expect(MyTask).to have_callback(:before_execution)
#
# @example Testing callback with specific callable
#   class ProcessTask < CMDx::Task
#     after_execution :log_completion
#     def call; end
#   end
#   expect(ProcessTask).to have_callback(:after_execution).with_callable(:log_completion)
#
# @example Testing callbacks with procs
#   class CustomTask < CMDx::Task
#     before_execution -> { puts "Starting" }
#     def call; end
#   end
#   expect(CustomTask).to have_callback(:before_execution)
#
# @example Negative assertion
#   class SimpleTask < CMDx::Task
#     def call; end
#   end
#   expect(SimpleTask).not_to have_callback(:before_execution)
RSpec::Matchers.define :have_callback do |callback_name|
  match do |task_class|
    task_class.cmd_callbacks.registered?(callback_name)
  end

  chain :with_callable do |callable|
    @expected_callable = callable
  end

  match do |task_class|
    callbacks_registered = task_class.cmd_callbacks.registered?(callback_name)
    return false unless callbacks_registered

    if @expected_callable
      task_class.cmd_callbacks.find(callback_name).any? do |callback|
        callback.callable == @expected_callable
      end
    else
      true
    end
  end

  failure_message do |task_class|
    if @expected_callable
      "expected task to have callback #{callback_name} with callable #{@expected_callable}, but it didn't"
    else
      registered_callbacks = task_class.cmd_callbacks.registered_callbacks
      "expected task to have callback #{callback_name}, but had #{registered_callbacks}"
    end
  end

  failure_message_when_negated do |_task_class|
    if @expected_callable
      "expected task not to have callback #{callback_name} with callable #{@expected_callable}, but it did"
    else
      "expected task not to have callback #{callback_name}, but it did"
    end
  end

  description do
    desc = "have callback #{callback_name}"
    desc += " with callable #{@expected_callable}" if @expected_callable
    desc
  end
end
