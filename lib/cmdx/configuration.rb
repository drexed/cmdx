# frozen_string_literal: true

module CMDx
  # Global configuration with sensible defaults.
  # Modify via `CMDx.configure { |c| c.logger = ... }`.
  class Configuration

    # @return [Logger] the global logger instance
    # @rbs @logger: Logger
    attr_accessor :logger

    # @return [Symbol, nil] global log level override
    # @rbs @log_level: Symbol?
    attr_accessor :log_level

    # @return [Proc, nil] global log formatter override
    # @rbs @log_formatter: Proc?
    attr_accessor :log_formatter

    # @return [Boolean] whether to raise faults on validation errors
    # @rbs @strict_attributes: bool
    attr_accessor :strict_attributes

    # @rbs () -> void
    def initialize
      @logger = default_logger
      @log_level = nil
      @log_formatter = nil
      @strict_attributes = true
    end

    private

    # @rbs () -> Logger
    def default_logger
      ::Logger.new($stdout, level: ::Logger::INFO)
    end

  end
end
