# frozen_string_literal: true

module CMDx
  # Builds structured log data from a Result and dispatches to the logger.
  module LogEntry

    # Log a task result.
    #
    # @param result [CMDx::Result]
    # @param settings [CMDx::Settings]
    # @return [void]
    def self.log(result, settings)
      logger = settings.logger || CMDx.configuration.logger
      return unless logger

      data = build(result, settings)
      level = settings.log_level || :info
      formatter = settings.log_formatter

      if formatter
        logger.add(severity_level(level), formatter.call(data))
      else
        logger.public_send(level, "cmdx") { data.inspect }
      end
    end

    # Build the structured log data hash.
    #
    # @param result [CMDx::Result]
    # @param settings [CMDx::Settings]
    # @return [Hash]
    def self.build(result, settings)
      task = result.task
      is_workflow = task.class.respond_to?(:workflow_tasks)

      data = {
        index: result.index,
        chain_id: result.chain&.id,
        type: is_workflow ? "Workflow" : "Task",
        tags: settings.tags,
        class: task.class.name,
        dry_run: result.dry_run?,
        id: task.id,
        state: result.state,
        status: result.status,
        outcome: result.outcome,
        metadata: result.metadata
      }

      if result.interrupted?
        data[:reason] = result.reason
        data[:cause] = result.cause
        data[:rolled_back] = result.rolled_back?
      end

      data[:retries] = result.retries if result.retried?

      data[:context] = result.context.to_h if settings.dump_context

      if result.failed? && result.metadata[:threw_from]
        data[:threw_failure] = result.metadata[:threw_from]
        data[:caused_failure] = result.metadata[:caused_by]
      end

      data
    end

    # @param level [Symbol]
    # @return [Integer]
    def self.severity_level(level)
      case level.to_sym
      when :debug then Logger::DEBUG
      when :warn  then Logger::WARN
      when :error then Logger::ERROR
      when :fatal then Logger::FATAL
      else Logger::INFO
      end
    end

  end
end
