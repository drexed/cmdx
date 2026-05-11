# frozen_string_literal: true

CMDx.configure do |config|
  # Full configuration reference:
  # https://drexed.github.io/cmdx/configuration

  # ===========================================================================
  # Default locale
  # https://drexed.github.io/cmdx/configuration/#default-locale
  # ===========================================================================
  # The language CMDx uses for its built-in messages (validation errors,
  # coercion errors, etc.) when the `I18n` gem isn't around. If `I18n` IS
  # loaded, CMDx follows `I18n.locale` and ignores this setting.
  #
  # config.default_locale = "en"

  # ===========================================================================
  # Strict context
  # https://drexed.github.io/cmdx/configuration/#strict-context
  # ===========================================================================
  # Catches typos early. With strict mode on, `context.usr_id` (instead of
  # `context.user_id`) raises `CMDx::UnknownAccessorError` instead of silently
  # returning `nil`. Hash-style reads (`[]`, `fetch`, `dig`, `?` predicates)
  # stay forgiving. Flip it per task with `settings(strict_context: true)`.
  #
  # config.strict_context = true

  # ===========================================================================
  # Correlation ID (xid)
  # https://drexed.github.io/cmdx/configuration/#correlation-id-xid
  # ===========================================================================
  # Stamps every task in a run with the same id so you can grep your logs by
  # request. The callable runs ONCE per root execution; every nested task
  # inherits the value. Surfaces as `result.xid`, `result.to_h[:xid]`, and
  # `event.xid` on telemetry events.
  #
  # config.correlation_id = -> { Current.request_id }

  # ===========================================================================
  # Logging
  # https://drexed.github.io/cmdx/configuration/#logging
  # ===========================================================================
  # Pick where logs go, how they look, and what to hide. In Rails, the Railtie
  # already points `logger` at `Rails.logger` and wires a backtrace cleaner —
  # only override here if you want something different.
  #
  # Built-in formatters (under `CMDx::LogFormatters`):
  #   Line (default), JSON, KeyValue, Logstash, Raw
  #
  # `log_exclusions` only strips keys from the LOG LINE — the in-memory
  # `Result` and telemetry payloads stay complete.
  #
  # config.backtrace_cleaner = ->(bt) { Rails.backtrace_cleaner.clean(bt) }
  # config.log_exclusions = [:context]
  # config.log_formatter  = CMDx::LogFormatters::Line.new
  # config.log_level      = Logger::INFO
  # config.logger         = Logger.new($stdout, progname: "cmdx")

  # ===========================================================================
  # Middlewares
  # https://drexed.github.io/cmdx/configuration/#middlewares
  # ===========================================================================
  # Wrap every task with shared behavior (auth, locale, timing, you name it).
  # A middleware is anything that responds to `call(task) { ... }` and MUST
  # yield (or call `next_link.call` from a proc) — forgetting to do so raises
  # `CMDx::MiddlewareError` so tasks never silently disappear.
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
  # https://drexed.github.io/cmdx/configuration/#callbacks
  # ===========================================================================
  # Hook into a task's lifecycle. Each callback receives the task instance.
  #
  # Available events:
  #   :before_execution, :before_validation,
  #   :around_execution, :after_execution,
  #   :on_complete, :on_interrupted,
  #   :on_success, :on_skipped, :on_failed,
  #   :on_ok, :on_ko
  #
  # config.callbacks.register(:on_failed, proc do |task|
  #   Rails.logger.error("[cmdx] #{task.class.name} failed: #{task.metadata[:reason]}")
  # end)

  # ===========================================================================
  # Telemetry
  # https://drexed.github.io/cmdx/configuration/#telemetry
  # ===========================================================================
  # A tiny pub/sub bus for runtime events. Subscribe with a callable; nothing
  # fires if nobody's listening, so unused events cost nothing.
  #
  # Events and their extra payload keys:
  #   :task_started      {}
  #   :task_deprecated   {}
  #   :task_retried      { attempt: Integer }
  #   :task_rolled_back  {}
  #   :task_executed     { result: CMDx::Result }
  #
  # Every event also carries: event.cid, event.xid, event.tid, event.task,
  # event.type, event.name, event.root, event.payload, event.timestamp.
  #
  # config.telemetry.subscribe(:task_executed, proc do |event|
  #   StatsD.timing("cmdx.task", event.payload[:result].duration)
  # end)

  # ===========================================================================
  # Coercions
  # https://drexed.github.io/cmdx/configuration/#coercions
  # ===========================================================================
  # Teach CMDx how to convert raw input into a custom type. The callable gets
  # `(value, **options)` and returns the coerced value (or
  # `CMDx::Coercions::Failure.new("message")` to signal a bad value).
  #
  # config.coercions.register(:currency, proc do |value, **|
  #   BigDecimal(value.to_s.gsub(/[^\d.-]/, ""))
  # end)

  # ===========================================================================
  # Validators
  # https://drexed.github.io/cmdx/configuration/#validators
  # ===========================================================================
  # Custom input validators. The callable gets `(value, options)` (options is
  # a positional Hash). Return `CMDx::Validators::Failure.new(message)` to
  # fail — anything else (even `nil`) means the value passed.
  #
  # config.validators.register(:uuid, proc do |value, _options|
  #   unless value.to_s.match?(/\A[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i)
  #     CMDx::Validators::Failure.new("is not a valid UUID")
  #   end
  # end)

  # ===========================================================================
  # Retriers
  # https://drexed.github.io/cmdx/retries/
  # ===========================================================================
  # Retriers decide how long to wait between `retry_on` attempts. A callable
  # gets `(attempt, delay, prev_delay)` and returns the next sleep in seconds.
  #
  # Built-ins: :exponential (default), :linear, :fibonacci, :half_random,
  # :full_random, :bounded_random, :decorrelated_jitter.
  #
  # config.retriers.register(:capped_exponential, proc do |attempt, delay, _prev|
  #   [delay * (2**(attempt - 1)), 30.0].min
  # end)

  # ===========================================================================
  # Deprecators
  # https://drexed.github.io/cmdx/deprecation/
  # ===========================================================================
  # Decide what happens when a task with a `deprecation` declaration runs —
  # log a warning, raise, ping your error tracker, whatever you like. The
  # callable receives the task instance.
  #
  # Built-ins: :log, :warn, :error.
  #
  # config.deprecators.register(:notify, proc do |task|
  #   Bugsnag.notify("Deprecated task invoked: #{task.class.name}")
  # end)

  # ===========================================================================
  # Executors
  # https://drexed.github.io/cmdx/workflows/#parallel-execution
  # ===========================================================================
  # Executors power `:parallel` workflow groups. The callable gets
  # `(jobs:, concurrency:, on_job:)`, runs `on_job.call(job)` for every job,
  # and blocks until every job is done.
  #
  # Built-ins: :threads (default), :fibers.
  #
  # config.executors.register(:ractors, proc do |jobs:, concurrency:, on_job:|
  #   jobs.each_slice(concurrency) do |slice|
  #     slice.map { |job| Ractor.new(job) { |j| on_job.call(j) } }.each(&:take)
  #   end
  # end)

  # ===========================================================================
  # Mergers
  # https://drexed.github.io/cmdx/workflows/#parallel-execution
  # ===========================================================================
  # After parallel branches succeed, a merger folds each branch's context back
  # into the workflow context. The callable gets `(workflow_context, result)`.
  #
  # Built-ins: :last_write_wins (default), :deep_merge, :no_merge.
  #
  # config.mergers.register(:whitelist, proc do |workflow_context, result|
  #   result.context.to_h.slice(:order_id, :total).each do |key, value|
  #     workflow_context[key] = value
  #   end
  # end)
end
