# frozen_string_literal: true

RSpec::Matchers.define :use_default_value do |parameter_name, default_value|
  match do |task_class|
    result = task_class.call
    result.success? &&
      result.context.public_send(parameter_name) == default_value
  end

  failure_message do |task_class|
    result = task_class.call
    if result.failed?
      "expected task to use default value #{default_value} for #{parameter_name}, but task failed: #{result.metadata[:reason]}"
    else
      actual_value = result.context.public_send(parameter_name)
      "expected task to use default value #{default_value} for #{parameter_name}, but was #{actual_value}"
    end
  end

  failure_message_when_negated do |_task_class|
    "expected task not to use default value #{default_value} for #{parameter_name}, but it did"
  end

  description do
    "use default value #{default_value} for parameter #{parameter_name}"
  end
end
