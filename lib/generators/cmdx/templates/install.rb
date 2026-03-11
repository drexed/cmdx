# frozen_string_literal: true

CMDx.configure do |config|
  # Task breakpoint configuration - controls when execute! raises faults
  # See https://github.com/drexed/cmdx/blob/main/docs/outcomes/statuses.md for more details
  #
  # Available statuses: "success", "skipped", "failed"
  # If set to an empty array, task will never halt
  config.task_breakpoints = %w[failed]

  # Workflow breakpoint configuration - controls when workflows stop execution
  # When a task returns these statuses, subsequent workflow tasks won't execute
  # See https://github.com/drexed/cmdx/blob/main/docs/workflow.md for more details
  #
  # Available statuses: "success", "skipped", "failed"
  # If set to an empty array, workflow will never halt
  config.workflow_breakpoints = %w[failed]

  # Logger configuration - choose from multiple formatters
  # See https://github.com/drexed/cmdx/blob/main/docs/logging.md for more details
  #
  # Available formatters:
  # - CMDx::LogFormatters::Json
  # - CMDx::LogFormatters::KeyValue
  # - CMDx::LogFormatters::Line
  # - CMDx::LogFormatters::Logstash
  # - CMDx::LogFormatters::Raw
  config.logger = Logger.new(
    $stdout,
    progname: "cmdx",
    formatter: CMDx::LogFormatters::Line.new,
    level: Logger::INFO
  )

  # Rollback configuration - controls which statuses trigger task rollback
  # See https://github.com/drexed/cmdx/blob/main/docs/outcomes/statuses.md for more details
  #
  # Available statuses: "success", "skipped", "failed"
  # If set to an empty array, task will never rollback
  config.rollback_on = %w[failed]

  # Default locale configuration - used for built-in translation lookups
  # Must match the basename of a YAML file in lib/locales/ (e.g. "en", "es", "ja")
  # config.default_locale = "en"

  # Backtrace configuration - controls whether to log backtraces on faults and exceptions
  # https://github.com/drexed/cmdx/blob/main/docs/getting_started.md#backtraces
  # config.backtrace = false
  # config.backtrace_cleaner = nil

  # Exception handler configuration - called when non-fault exceptions are raised
  # https://github.com/drexed/cmdx/blob/main/docs/getting_started.md#exception-handler
  # config.exception_handler = nil

  # Additional global configurations - automatically applied to all tasks
  #
  # Middlewares - https://github.com/drexed/cmdx/blob/main/docs/middlewares.md
  # Callbacks - https://github.com/drexed/cmdx/blob/main/docs/callbacks.md
  # Coercions - https://github.com/drexed/cmdx/blob/main/docs/coercions.md
  # Validations - https://github.com/drexed/cmdx/blob/main/docs/validations.md
end
