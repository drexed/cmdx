# frozen_string_literal: true

module CMDx
  # Global configuration with sensible defaults.
  # Holds framework-wide settings and global middleware/callback registries.
  class Configuration

    attr_accessor :task_breakpoints, :workflow_breakpoints, :rollback_on,
                  :dump_context, :freeze_results,
                  :backtrace, :backtrace_cleaner, :exception_handler,
                  :logger

    def initialize
      @task_breakpoints = %w[failed]
      @workflow_breakpoints = %w[failed]
      @rollback_on = %w[failed]
      @dump_context = false
      @freeze_results = true
      @backtrace = false
      @backtrace_cleaner = nil
      @exception_handler = nil
      @logger = default_logger
      @middlewares = []
      @callbacks = Hash.new { |h, k| h[k] = [] }
    end

    # -- Global middleware registry --

    # @return [Array]
    attr_reader :middlewares

    # -- Global callback registry --

    # @return [Hash]
    attr_reader :callbacks

    private

    def default_logger
      log = Logger.new($stdout)
      log.level = Logger::INFO
      log.progname = "cmdx"
      log
    end

  end
end
