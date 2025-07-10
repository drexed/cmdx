# frozen_string_literal: true

RSpec::Matchers.define :have_task_setting do |setting_name, expected_value = nil|
  match do |task_class|
    return false unless task_class.task_setting?(setting_name)

    if expected_value
      task_class.task_setting(setting_name) == expected_value
    else
      true
    end
  end

  failure_message do |task_class|
    if expected_value
      actual_value = task_class.task_setting(setting_name)
      "expected task to have setting #{setting_name} with value #{expected_value}, but was #{actual_value}"
    else
      available_settings = task_class.task_settings.keys
      "expected task to have setting #{setting_name}, but had #{available_settings}"
    end
  end

  failure_message_when_negated do |_task_class|
    if expected_value
      "expected task not to have setting #{setting_name} with value #{expected_value}, but it did"
    else
      "expected task not to have setting #{setting_name}, but it did"
    end
  end

  description do
    desc = "have task setting #{setting_name}"
    desc += " with value #{expected_value}" if expected_value
    desc
  end
end
