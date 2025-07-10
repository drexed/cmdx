# frozen_string_literal: true

RSpec::Matchers.define :validate_required_parameter do |parameter_name|
  match do |task_class|
    result = task_class.call
    result.failed? &&
      result.metadata[:reason]&.include?("#{parameter_name} is a required parameter")
  end

  failure_message do |task_class|
    result = task_class.call
    if result.success?
      "expected task to fail validation for required parameter #{parameter_name}, but it succeeded"
    elsif result.failed?
      "expected task to fail with message about required parameter #{parameter_name}, but failed with: #{result.metadata[:reason]}"
    else
      "expected task to fail validation for required parameter #{parameter_name}, but was #{result.status}"
    end
  end

  failure_message_when_negated do |_task_class|
    "expected task not to validate required parameter #{parameter_name}, but it did"
  end

  description do
    "validate required parameter #{parameter_name}"
  end
end
