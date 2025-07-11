# frozen_string_literal: true

module CMDx
  class Result

    cmdx_attr_delegator :context, :chain,
                        to: :task

    # @return [CMDx::Task] The task instance that generated this result
    attr_reader :task

    # @return [String] The current execution state (initialized, executing, complete, interrupted)
    attr_reader :state

    # @return [String] The current execution status (success, skipped, failed)
    attr_reader :status

    # @return [Hash] Additional metadata associated with the result
    attr_reader :metadata

    def initialize(task)
      raise TypeError, "must be a Task or Workflow" unless task.is_a?(Task)

      @task     = task
      @state    = INITIALIZED
      @status   = SUCCESS
      @metadata = {}
    end

    STATES = [
      INITIALIZED = "initialized",  # Initial state before execution
      EXECUTING   = "executing",    # Currently executing task logic
      COMPLETE    = "complete",     # Successfully completed execution
      INTERRUPTED = "interrupted"   # Execution was halted due to failure
    ].freeze

    STATES.each do |s|
      # eg: executing?
      define_method(:"#{s}?") { state == s }

      # eg: on_interrupted { ... }
      define_method(:"on_#{s}") do |&block|
        raise ArgumentError, "block required" unless block

        block.call(self) if send(:"#{s}?")
        self
      end
    end

    def executed!
      success? ? complete! : interrupt!
    end

    def executed?
      complete? || interrupted?
    end

    def on_executed(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if executed?
      self
    end

    def executing!
      return if executing?

      raise "can only transition to #{EXECUTING} from #{INITIALIZED}" unless initialized?

      @state = EXECUTING
    end

    def complete!
      return if complete?

      raise "can only transition to #{COMPLETE} from #{EXECUTING}" unless executing?

      @state = COMPLETE
    end

    def interrupt!
      return if interrupted?

      raise "cannot transition to #{INTERRUPTED} from #{COMPLETE}" if complete?

      @state = INTERRUPTED
    end

    STATUSES = [
      SUCCESS = "success",  # Task completed successfully
      SKIPPED = "skipped",  # Task was skipped intentionally
      FAILED  = "failed"    # Task failed due to error or validation
    ].freeze

    STATUSES.each do |s|
      # eg: skipped?
      define_method(:"#{s}?") { status == s }

      # eg: on_failed { ... }
      define_method(:"on_#{s}") do |&block|
        raise ArgumentError, "block required" unless block

        block.call(self) if send(:"#{s}?")
        self
      end
    end

    def good?
      !failed?
    end

    def on_good(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if good?
      self
    end

    def bad?
      !success?
    end

    def on_bad(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if bad?
      self
    end

    def skip!(**metadata)
      return if skipped?

      raise "can only transition to #{SKIPPED} from #{SUCCESS}" unless success?

      @status   = SKIPPED
      @metadata = metadata

      halt! unless metadata[:original_exception]
    end

    def fail!(**metadata)
      return if failed?

      raise "can only transition to #{FAILED} from #{SUCCESS}" unless success?

      @status   = FAILED
      @metadata = metadata

      halt! unless metadata[:original_exception]
    end

    def halt!
      return if success?

      raise Fault.build(self)
    end

    def throw!(result, local_metadata = {})
      raise TypeError, "must be a Result" unless result.is_a?(Result)

      md = result.metadata.merge(local_metadata)

      skip!(**md) if result.skipped?
      fail!(**md) if result.failed?
    end

    def caused_failure
      return unless failed?

      chain.results.reverse.find(&:failed?)
    end

    def caused_failure?
      return false unless failed?

      caused_failure == self
    end

    def threw_failure
      return unless failed?

      results = chain.results.select(&:failed?)
      results.find { |r| r.index > index } || results.last
    end

    def threw_failure?
      return false unless failed?

      threw_failure == self
    end

    def thrown_failure?
      failed? && !caused_failure?
    end

    def index
      chain.index(self)
    end

    def outcome
      initialized? || thrown_failure? ? state : status
    end

    def runtime(&)
      return @runtime unless block_given?

      @runtime = Utils::MonotonicRuntime.call(&)
    end

    def to_h
      ResultSerializer.call(self)
    end

    def to_s
      ResultInspector.call(to_h)
    end

    def deconstruct
      [state, status]
    end

    def deconstruct_keys(keys)
      attributes = {
        state: state,
        status: status,
        metadata: metadata,
        executed: executed?,
        good: good?,
        bad: bad?
      }

      return attributes if keys.nil?

      attributes.slice(*keys)
    end

  end
end
