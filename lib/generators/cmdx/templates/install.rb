# frozen_string_literal: true

CMDx.configure do |config|
  # Halt execution and raise fault on these result statuses when using `call!`
  config.task_halt = CMDx::Result::FAILED

  # Global timeout for individual tasks (nil = no timeout)

  # Stop batch execution when tasks return these statuses
  # Note: Skipped tasks continue processing by default
  config.batch_halt = CMDx::Result::FAILED

  # Global timeout for entire batch execution (nil = no timeout)
  # Tip: Account for all tasks when setting this value

  # Logger with formatter - see available formatters at:
  # https://github.com/drexed/cmdx/tree/main/lib/cmdx/log_formatters
  config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)
end
