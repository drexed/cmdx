# frozen_string_literal: true

module CMDx

  # Global defaults merged into each {Definition} root.
  class Configuration

    attr_accessor :logger, :telemetry, :freeze_results, :dump_context, :backtrace, :backtrace_cleaner, :exception_handler, :id_generator, :task_breakpoints, :workflow_breakpoints, :rollback_on, :sleep_impl

    def initialize
      @logger = Logger.new($stdout)
      @logger.progname = "CMDx"
      @telemetry = nil
      @freeze_results = true
      @dump_context = false
      @backtrace = false
      @backtrace_cleaner = nil
      @exception_handler = nil
      @id_generator = -> { Identifier.generate }
      @task_breakpoints = [:failed].freeze
      @workflow_breakpoints = [:failed].freeze
      @rollback_on = [:failed].freeze
      @sleep_impl = ->(seconds) { Kernel.sleep(seconds) }
      @extensions = ExtensionSet.build_defaults
    end

    # @return [ExtensionSet]
    attr_reader :extensions

    # @param ext [ExtensionSet]
    # @return [void]
    def extensions=(ext)
      @extensions = ext
      reset_base_definition!
    end

    # @return [Definition]
    def base_definition
      @base_definition ||= Definition.root(self)
    end

    # @return [void]
    def reset_base_definition!
      remove_instance_variable(:@base_definition) if instance_variable_defined?(:@base_definition)
    end

    class << self

      # @return [Configuration]
      def instance
        @instance ||= new
      end

      # @yieldparam config [Configuration]
      # @return [void]
      def configure
        yield instance
        instance.reset_base_definition!
      end

      # @return [void]
      def reset!
        @instance = new
      end

    end

  end

  # @return [Configuration]
  def self.configuration
    Configuration.instance
  end

  # @see Configuration#configure
  def self.configure(&)
    Configuration.configure(&)
  end

  # @return [void]
  def self.reset_configuration!
    Configuration.reset!
  end

end
