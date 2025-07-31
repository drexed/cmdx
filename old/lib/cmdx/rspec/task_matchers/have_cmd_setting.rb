# frozen_string_literal: true

# RSpec matcher for asserting that a task class has a specific task setting.
#
# This matcher checks if a CMDx::Task class has registered a task setting with the
# specified name. Task settings are configuration options that control task behavior
# such as execution timeouts, retry policies, or custom flags. The matcher can
# optionally verify that the setting has a specific value for more precise validation.
#
# @param setting_name [Symbol, String] the name of the task setting to check for
# @param expected_value [Object, nil] the expected value of the setting (optional)
#
# @return [Boolean] true if the task has the specified setting and optionally the expected value
#
# @example Testing basic task setting presence
#   class MyTask < CMDx::Task
#     cmd_setting tags: ["admin"]
#     def call; end
#   end
#   expect(MyTask).to have_cmd_setting(:tags)
#
# @example Testing task setting with specific value
#   class ProcessTask < CMDx::Task
#     cmd_setting tags: ["admin"]
#     def call; end
#   end
#   expect(ProcessTask).to have_cmd_setting(:tags, ["admin"])
#
# @example Negative assertion
#   class SimpleTask < CMDx::Task
#     def call; end
#   end
#   expect(SimpleTask).not_to have_cmd_setting(:tags)
RSpec::Matchers.define :have_cmd_setting do |setting_name, expected_value = nil|
  match do |task_class|
    return false unless task_class.cmd_setting?(setting_name)

    if expected_value
      task_class.cmd_setting(setting_name) == expected_value
    else
      true
    end
  end

  failure_message do |task_class|
    if expected_value
      actual_value = task_class.cmd_setting(setting_name)
      "expected task to have setting #{setting_name} with value #{expected_value}, but was #{actual_value}"
    else
      available_settings = task_class.cmd_settings.keys
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
