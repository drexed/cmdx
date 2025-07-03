# frozen_string_literal: true

module CMDx
  # Logger configuration and setup module for CMDx tasks.
  #
  # The Logger module provides centralized logger configuration and initialization
  # for CMDx tasks. It handles logger setup, formatter assignment, log level
  # configuration, and progname assignment based on task settings.
  #
  # @example Basic logger usage
  #   class ProcessOrderTask < CMDx::Task
  #     def call
  #       logger.info "Processing order #{order_id}"
  #       logger.debug { "Order details: #{order.inspect}" }
  #     end
  #   end
  #
  # @example Task-specific logger configuration
  #   class ProcessOrderTask < CMDx::Task
  #     task_settings!(
  #       logger: Rails.logger,
  #       log_formatter: CMDx::LogFormatters::Json.new,
  #       log_level: Logger::INFO
  #     )
  #   end
  #
  # @example Global logger configuration
  #   CMDx.configure do |config|
  #     config.logger = Logger.new($stdout)
  #     config.log_formatter = CMDx::LogFormatters::PrettyLine.new
  #     config.log_level = Logger::WARN
  #   end
  #
  # @example Custom logger with specific formatter
  #   logger = Logger.new(STDOUT)
  #   logger.formatter = CMDx::LogFormatters::Logstash.new
  #   logger.level = Logger::DEBUG
  #
  #   class MyTask < CMDx::Task
  #     task_settings!(logger: logger)
  #   end
  #
  # @see CMDx::LogFormatters Log formatting options
  # @see CMDx::ResultLogger Result-specific logging functionality
  # @see CMDx::Task Task logging integration
  module Logger

    module_function

    # Configures and returns a logger instance for a task.
    #
    # Retrieves the logger from task settings and applies additional configuration
    # including formatter, log level, and progname if specified in task settings.
    # Returns nil if no logger is configured.
    #
    # @param task [CMDx::Task] The task instance to configure logging for
    # @return [::Logger, nil] Configured logger instance or nil if not set
    #
    # @example Basic logger retrieval
    #   task = ProcessOrderTask.new
    #   logger = Logger.call(task)
    #   logger.info "Task started" if logger
    #
    # @example Logger with custom formatter
    #   class MyTask < CMDx::Task
    #     task_settings!(
    #       logger: Logger.new(STDOUT),
    #       log_formatter: CMDx::LogFormatters::Json.new
    #     )
    #   end
    #
    #   task = MyTask.new
    #   logger = Logger.call(task)  # Logger with JSON formatter applied
    #
    # @example Logger with custom level
    #   class MyTask < CMDx::Task
    #     task_settings!(
    #       logger: Logger.new(STDOUT),
    #       log_level: Logger::DEBUG
    #     )
    #   end
    #
    #   task = MyTask.new
    #   logger = Logger.call(task)  # Logger with DEBUG level applied
    #
    # @example No logger configured
    #   class MyTask < CMDx::Task
    #     # No logger setting
    #   end
    #
    #   task = MyTask.new
    #   logger = Logger.call(task)  # => nil
    def call(task)
      logger = task.task_setting(:logger)

      unless logger.nil?
        logger.formatter = task.task_setting(:log_formatter) if task.task_setting?(:log_formatter)
        logger.level     = task.task_setting(:log_level) if task.task_setting?(:log_level)
        logger.progname  = task
      end

      logger
    end

  end
end
