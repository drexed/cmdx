# frozen_string_literal: true

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
