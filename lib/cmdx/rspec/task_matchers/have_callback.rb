# frozen_string_literal: true

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
