# frozen_string_literal: true

# RSpec matcher for asserting that a task class has a specific middleware.
#
# This matcher checks if a CMDx::Task class has registered a middleware of the
# specified class. Middlewares are components that wrap around task execution to
# provide cross-cutting concerns like logging, timing, error handling, or other
# aspects. The matcher verifies that the middleware is properly registered and
# available for execution during task performance.
#
# @param middleware_class [Class] the middleware class to check for
#
# @return [Boolean] true if the task has the specified middleware class registered
#
# @example Testing middleware registration
#   class MyTask < CMDx::Task
#     use :middleware, CMDx::Middlewares::Timeout, timeout: 10
#     def call; end
#   end
#   expect(MyTask).to have_middleware(TimeoutMiddleware)
#
# @example Negative assertion
#   class SimpleTask < CMDx::Task
#     def call; end
#   end
#   expect(SimpleTask).not_to have_middleware(TimeoutMiddleware)
#
# @since 1.0.0
RSpec::Matchers.define :have_middleware do |middleware_class|
  match do |task_class|
    task_class.cmd_middlewares.any? do |middleware|
      middleware.is_a?(middleware_class) || middleware.instance_of?(middleware_class)
    end
  end

  failure_message do |task_class|
    middleware_classes = task_class.cmd_middlewares.map(&:class)
    "expected task to have middleware #{middleware_class}, but had #{middleware_classes}"
  end

  failure_message_when_negated do |_task_class|
    "expected task not to have middleware #{middleware_class}, but it did"
  end

  description do
    "have middleware #{middleware_class}"
  end
end
