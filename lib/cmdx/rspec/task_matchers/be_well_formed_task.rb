# frozen_string_literal: true

RSpec::Matchers.define :be_well_formed_task do
  match do |task_class|
    task_class < CMDx::Task &&
      task_class.instance_methods.include?(:call) &&
      task_class.cmd_parameters.is_a?(CMDx::ParameterRegistry) &&
      task_class.cmd_callbacks.is_a?(CMDx::CallbackRegistry) &&
      task_class.cmd_middlewares.is_a?(CMDx::MiddlewareRegistry)
  end

  failure_message do |task_class|
    issues = []
    issues << "does not inherit from CMDx::Task" unless task_class < CMDx::Task
    issues << "does not implement call method" unless task_class.instance_methods.include?(:call)
    issues << "does not have parameter registry" unless task_class.cmd_parameters.is_a?(CMDx::ParameterRegistry)
    issues << "does not have callback registry" unless task_class.cmd_callbacks.is_a?(CMDx::CallbackRegistry)
    issues << "does not have middleware registry" unless task_class.cmd_middlewares.is_a?(CMDx::MiddlewareRegistry)

    "expected task to be well-formed, but #{issues.join(', ')}"
  end

  failure_message_when_negated do |_task_class|
    "expected task not to be well-formed, but it was"
  end

  description do
    "be a well-formed task"
  end
end
