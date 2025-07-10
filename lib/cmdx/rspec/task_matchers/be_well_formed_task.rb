# frozen_string_literal: true

# RSpec matcher for asserting that a task class is well-formed.
#
# This matcher checks if a task class meets all the requirements to be a properly
# structured CMDx::Task. A well-formed task must inherit from CMDx::Task, implement
# the call method, and have properly initialized registries for parameters, callbacks,
# and middlewares. This is essential for ensuring task classes will function correctly
# within the CMDx framework and can be used in workflows.
#
# @return [Boolean] true if the task class is well-formed with all required components
#
# @example Testing a basic task class
#   class MyTask < CMDx::Task
#     def call; end
#   end
#   expect(MyTask).to be_well_formed_task
#
# @example Testing a task with parameters, callbacks and middlewares
#   class ComplexTask < CMDx::Task
#     before_validation :refresh_cache
#     use :middleware, CMDx::Middlewares::Timeout, timeout: 10
#     required :data
#     def call; end
#   end
#   expect(ComplexTask).to be_well_formed_task
#
# @example Testing generated task classes
#   task_class = Class.new(CMDx::Task) { def call; end }
#   expect(task_class).to be_well_formed_task
#
# @example Negative assertion for malformed tasks
#   class BrokenTask; end  # Missing inheritance
#   expect(BrokenTask).not_to be_well_formed_task
#
# @since 1.0.0
RSpec::Matchers.define :be_well_formed_task do
  match do |task_class|
    (task_class < CMDx::Task) &&
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
