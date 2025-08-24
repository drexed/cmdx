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

  # Additional global configurations - automatically applied to all tasks
  #
  # Middlewares - https://github.com/drexed/cmdx/blob/main/docs/middlewares.md
  # Callbacks - https://github.com/drexed/cmdx/blob/main/docs/callbacks.md
  # Coercions - https://github.com/drexed/cmdx/blob/main/docs/coercions.md
  # Validations - https://github.com/drexed/cmdx/blob/main/docs/validations.md
end
