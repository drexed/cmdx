# frozen_string_literal: true

CMDx.configure do |config|
  # ===========================================================================
  # Locale
  # ===========================================================================
  # Fallback locale for built-in messages (validation, coercion, etc.) when
  # the I18n gem is not present. With I18n loaded, CMDx follows `I18n.locale`.
  #
  # config.default_locale = "en"

  # ===========================================================================
  # Logging
  # ===========================================================================
  # In Rails, the Railtie already wires `config.logger = Rails.logger` and a
  # backtrace cleaner — override here only if you need something different.
  #
  # Formatters: Line (default), Json, KeyValue, Logstash, Raw
  #
  # config.logger        = Logger.new($stdout, progname: "cmdx")
  # config.log_level     = Logger::INFO
  # config.log_formatter = CMDx::LogFormatters::Line.new
  # config.backtrace_cleaner = ->(bt) { Rails.backtrace_cleaner.clean(bt) }

  # ===========================================================================
  # Middlewares
  # ===========================================================================
  # Wrap every task's execution. Must respond to `call(task) { ... }`.
  #
  # Example — run each task under the current user's locale:
  #
  # config.middlewares.register(proc do |task, &next_link|
  #   locale = Current.user.locale || I18n.default_locale
  #   I18n.with_locale(locale) do
  #     task.metadata[:locale] = locale
  #     next_link.call
  #   end
  # end)

  # ===========================================================================
  # Callbacks
  # ===========================================================================
  # Events:
  #   :before_validation, :before_execution,
  #   :on_complete, :on_interrupted,
  #   :on_success, :on_skipped, :on_failed,
  #   :on_ok, :on_ko
  #
  # config.callbacks.register(:on_failed, proc do |task|
  #   Rails.logger.error("[cmdx] #{task.class.name} failed: #{task.result.metadata[:reason]}")
  # end)

  # ===========================================================================
  # Telemetry
  # ===========================================================================
  # Events:
  #   :task_started, :task_deprecated, :task_retried,
  #   :task_rolled_back, :task_executed
  #
  # config.telemetry.subscribe(:task_executed, proc do |event|
  #   StatsD.timing("cmdx.#{event.name}", event.payload[:runtime])
  # end)

  # ===========================================================================
  # Coercions
  # ===========================================================================
  # Register custom type coercions. Callable receives `(value, **options)`.
  #
  # config.coercions.register(:currency, proc do |value, **|
  #   BigDecimal(value.to_s.gsub(/[^\d.-]/, ""))
  # end)

  # ===========================================================================
  # Validators
  # ===========================================================================
  # Register custom validators. Callable receives `(value, options)` and
  # returns a `CMDx::Validators::Failure.new(message)` on failure.
  #
  # config.validators.register(:uuid, proc do |value, _options|
  #   unless value.to_s.match?(/\A[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i)
  #     CMDx::Validators::Failure.new("is not a valid UUID")
  #   end
  # end)
end
