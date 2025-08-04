# frozen_string_literal: true

module CMDx
  module Logger

    extend self

    STATUS_TO_SEVERITY = {
      Result::SUCCESS => :info,
      Result::SKIPPED => :warn,
      Result::FAILED => :error
    }.freeze
    private_constant :STATUS_TO_SEVERITY

    def emit(task)
      return if task.logger.nil?

      severity = STATUS_TO_SEVERITY[task.result.status]

      task.logger.with_level(severity) do
        task.logger.send(severity) { task.result }
      end
    end

  end
end
