# frozen_string_literal: true

module CMDx
  module ResultLogger

    STATUS_TO_SEVERITY = {
      Result::SUCCESS => :info,   # Successful task completion
      Result::SKIPPED => :warn,   # Task was skipped
      Result::FAILED => :error    # Task execution failed
    }.freeze

    module_function

    def call(result)
      logger = result.task.send(:logger)
      return if logger.nil?

      severity = STATUS_TO_SEVERITY[result.status]

      logger.with_level(severity) do
        logger.send(severity) { result }
      end
    end

  end
end
