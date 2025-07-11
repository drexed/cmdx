# frozen_string_literal: true

module CMDx
  module ParameterValidator

    module_function

    def call(task)
      task.cmd_parameters.validate!(task)
      return if task.errors.empty?

      task.fail!(
        reason: task.errors.full_messages.join(". "),
        messages: task.errors.messages
      )
    end

  end
end
