# frozen_string_literal: true

module CMDx
  module ResultLogger

    STATUS_TO_SEVERITY = {
      Result::SUCCESS => :info,
      Result::SKIPPED => :warn,
      Result::FAILED => :error
    }.freeze

    module_function

    def call(result)
      logger   = result.task.send(:logger)
      severity = STATUS_TO_SEVERITY[result.status]

      logger.with_level(severity) do
        logger.send(severity) { result }
      end
    end

  end
end
