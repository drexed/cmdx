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
  # Strict context
  # ===========================================================================
  # When true, dynamic reads on `context` raise `NoMethodError` for unknown
  # keys instead of returning `nil` (`[]`, `fetch`, `dig`, and `?` predicates
  # stay lenient). Override per-task via `settings(strict_context: true)`.
  #
  # config.strict_context = true

  # ===========================================================================
  # Correlation ID (xid)
  # ===========================================================================
  # Resolves an external correlation id (e.g. Rails `request_id`) once per
  # root execution. The value is stored on the Chain and surfaces on every
  # Result (`result.xid`, `result.to_h[:xid]`) and Telemetry::Event (`event.xid`),
  # so all tasks within the same request can be filtered together in logs.
  #
  # config.correlation_id = -> { Current.request_id }

  # ===========================================================================
  # Logging
  # ===========================================================================
  # In Rails, the Railtie already wires `config.logger = Rails.logger` and a
  # backtrace cleaner — override here only if you need something different.
  #
  # Formatters: Line (default), Json, KeyValue, Logstash, Raw
  #
  # config.backtrace_cleaner = ->(bt) { Rails.backtrace_cleaner.clean(bt) }
  # config.log_exclusions = [:context]
  # config.log_formatter  = CMDx::LogFormatters::Line.new
  # config.log_level      = Logger::INFO
  # config.logger         = Logger.new($stdout, progname: "cmdx")

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
  #   Rails.logger.error("[cmdx] #{task.class.name} failed: #{task.metadata[:reason]}")
  # end)

  # ===========================================================================
  # Telemetry
  # ===========================================================================
  # Events and payloads:
  #   :task_started      payload: {}
  #   :task_deprecated   payload: {}
  #   :task_retried      payload: { attempt: Integer }
  #   :task_rolled_back  payload: {}
  #   :task_executed     payload: { result: CMDx::Result }
  #
  # Every event also carries: event.cid, event.xid, event.tid, event.task,
  # event.type, event.root, event.timestamp.
  #
  # config.telemetry.subscribe(:task_executed, proc do |event|
  #   StatsD.timing("cmdx.task", event.payload[:result].duration)
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

  # ===========================================================================
  # Executors
  # ===========================================================================
  # Registered executors drive `:parallel` workflow groups. Built-ins:
  # `:threads` (default), `:fibers`. A callable receives
  # `call(jobs:, concurrency:, on_job:)` and must invoke `on_job.call(job)`
  # for each job, blocking until every job is done.
  #
  # config.executors.register(:ractors, proc do |jobs:, concurrency:, on_job:|
  #   jobs.each_slice(concurrency) do |slice|
  #     slice.map { |job| Ractor.new(job) { |j| on_job.call(j) } }.each(&:take)
  #   end
  # end)

  # ===========================================================================
  # Mergers
  # ===========================================================================
  # Merge strategies fold successful parallel task contexts back into the
  # workflow context. Built-ins: `:last_write_wins` (default), `:deep_merge`,
  # `:no_merge`. A callable receives `call(workflow_context, result)`.
  #
  # config.mergers.register(:whitelist, proc do |workflow_context, result|
  #   result.context.to_h.slice(:order_id, :total).each do |key, value|
  #     workflow_context[key] = value
  #   end
  # end)
end
