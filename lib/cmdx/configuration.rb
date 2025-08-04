# frozen_string_literal: true

module CMDx

  class Configuration

    DEFAULT_BREAKPOINTS = %w[failed].freeze

    attr_accessor :middlewares, :callbacks, :coercions, :validators,
                  :task_breakpoints, :workflow_breakpoints, :logger

    # TODO: Change logger to a registry setup to allow loggers, statsd, etc.
    # https://www.prateekcodes.dev/rails-structured-event-reporting-system/#making-events-actually-useful-subscribers
    # https://boringrails.com/articles/event-sourcing-for-smooth-brains/
    # https://kopilov-vlad.medium.com/use-event-emitter-in-ruby-6b289fe2e7b4
    # https://github.com/sidekiq/sidekiq/blob/3f5cb77f954e91a1bf9306499725b22733c24298/lib/sidekiq/config.rb#L269
    # https://github.com/integrallis/stripe_event/blob/master/lib/stripe_event.rb
    def initialize
      @middlewares = MiddlewareRegistry.new
      @callbacks = CallbackRegistry.new
      @coercions = CoercionRegistry.new
      @validators = ValidatorRegistry.new

      @task_breakpoints = DEFAULT_BREAKPOINTS
      @workflow_breakpoints = DEFAULT_BREAKPOINTS

      @logger = Logger.new(
        $stdout,
        progname: "cmdx",
        formatter: LogFormatters::JSON.new,
        level: Logger::INFO
      )
    end

    def to_h
      {
        middlewares: @middlewares,
        callbacks: @callbacks,
        coercions: @coercions,
        validators: @validators,
        task_breakpoints: @task_breakpoints,
        workflow_breakpoints: @workflow_breakpoints,
        logger: @logger
      }
    end

  end

  extend self

  def configuration
    return @configuration if @configuration

    @configuration ||= Configuration.new
  end

  def configure
    raise ArgumentError, "block required" unless block_given?

    config = configuration
    yield(config)
    config
  end

  def reset_configuration!
    @configuration = Configuration.new
  end

end
