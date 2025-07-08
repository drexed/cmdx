# frozen_string_literal: true

CMDx.configure do |config|
  # Task halt configuration - controls when call! raises faults
  # See https://github.com/drexed/cmdx/blob/main/docs/outcomes/statuses.md for more details
  #
  # Available statuses: "success", "skipped", "failed"
  # If set to an empty array, task will never halt
  config.task_halt = %w[failed]

  # Workflow halt configuration - controls when workflows stop execution
  # When a task returns these statuses, subsequent workflow tasks won't execute
  # See https://github.com/drexed/cmdx/blob/main/docs/workflow.md for more details
  #
  # Available statuses: "success", "skipped", "failed"
  # If set to an empty array, workflow will never halt
  config.workflow_halt = %w[failed]

  # Logger configuration - choose from multiple formatters
  # See https://github.com/drexed/cmdx/blob/main/docs/logging.md for more details
  #
  # Available formatters:
  # - CMDx::LogFormatters::Line
  # - CMDx::LogFormatters::PrettyLine
  # - CMDx::LogFormatters::Json
  # - CMDx::LogFormatters::PrettyJson
  # - CMDx::LogFormatters::KeyValue
  # - CMDx::LogFormatters::PrettyKeyValue
  # - CMDx::LogFormatters::Logstash
  # - CMDx::LogFormatters::Raw
  config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)

  # Global middlewares - automatically applied to all tasks
  # See https://github.com/drexed/cmdx/blob/main/docs/middlewares.md for more details
  #
  # config.middlewares.use CMDx::Middlewares::Correlate
  # config.middlewares.use CMDx::Middlewares::Timeout, seconds: 30
  # config.middlewares.use CustomAuthMiddleware, if: :admin?
  # config.middlewares.use CustomPerfMiddleware.new(threshold: 5.0)

  # Global callbacks - automatically applied to all tasks
  # See https://github.com/drexed/cmdx/blob/main/docs/callbacks.md for more details
  #
  # config.callbacks.register :before_execution, :log_task_start
  # config.callbacks.register :after_execution, TrackTaskCompletion
  # config.callbacks.register :on_success, NotificationCallback.new(via: [:email, :slack])
  # config.callbacks.register :on_failure, :alert_support, if: :critical?
  # config.callbacks.register :on_complete, proc { |task, type|
  #   Metrics.increment("task.#{task.class.name.underscore}.completed")
  # }

  # Global coercions - custom parameter type conversions
  # See https://github.com/drexed/cmdx/blob/main/docs/parameters/coercions.md for more details
  #
  # config.coercions.register :money, MoneyCoercion
  # config.coercions.register :tags, TagsCoercion.new
  # config.coercions.register :slug, proc { |value|
  #   value.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/-+/, '-').strip('-')
  # }

  # Global validators - custom parameter validation logic
  # See https://github.com/drexed/cmdx/blob/main/docs/parameters/validations.md for more details
  #
  # config.validators.register :email, EmailValidator
  # config.validators.register :phone, PhoneValidator.new
  # config.validators.register :phone, proc { |value, options|
  #   PhoneValidator.validate(value, options)
  # }
end
