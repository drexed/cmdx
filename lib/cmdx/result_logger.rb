# frozen_string_literal: true

module CMDx
  module ResultLogger

    STATUS_TO_LEVEL = {
      Result::SUCCESS => :info,
      Result::SKIPPED => :warn,
      Result::FAILED => :error
    }.freeze

    module_function

    def call(result)
      logger = result.task.send(:logger)
      status = STATUS_TO_LEVEL[result.status]

      logger.with_level(result.task.task_setting(:log_level) || status) do
        logger.send(status) { result.to_h }
      end
    end

  end
end
