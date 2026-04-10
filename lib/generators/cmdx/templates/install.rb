# frozen_string_literal: true

CMDx.configure do |config|
  # Statuses for which +execute!+ raises {CMDx::FailFault} / {CMDx::SkipFault}
  config.task_breakpoints = %i[failed]

  # Workflow groups stop when a subtask finishes with one of these statuses
  config.workflow_breakpoints = %i[failed]

  config.logger = Logger.new($stdout, progname: "CMDx", level: Logger::INFO)

  # Statuses that call +rollback+ on the task when defined
  config.rollback_on = %i[failed]

  # Optional: structured sink (defaults to +Logger#info+ with a hash inspect)
  # config.telemetry = CMDx::Telemetry.new(logger: config.logger)

  # config.backtrace = false
  # config.backtrace_cleaner = nil
  # config.exception_handler = nil
  # config.dump_context = false
  # config.freeze_results = true
  #
  # Global defaults use {CMDx::ExtensionSet.build_defaults}. Override per task with +register+.
end
