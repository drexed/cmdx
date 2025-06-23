# frozen_string_literal: true

module CMDx
  class Result

    __cmdx_attr_delegator :context, :run, to: :task

    attr_reader :task, :state, :status, :metadata

    def initialize(task)
      raise TypeError, "must be a Task or Batch" unless task.is_a?(Task)

      @task     = task
      @state    = INITIALIZED
      @status   = SUCCESS
      @metadata = {}
    end

    STATES = [
      INITIALIZED = "initialized",
      EXECUTING   = "executing",
      COMPLETE    = "complete",
      INTERRUPTED = "interrupted"
    ].freeze

    STATES.each do |s|
      # eg: executing?
      define_method(:"#{s}?") { state == s }

      # eg: on_interrupted { ... }
      define_method(:"on_#{s}") do |&block|
        raise ArgumentError, "a block is required" unless block

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
      raise ArgumentError, "a block is required" unless block_given?

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
      SUCCESS = "success",
      SKIPPED = "skipped",
      FAILED  = "failed"
    ].freeze

    STATUSES.each do |s|
      # eg: skipped?
      define_method(:"#{s}?") { status == s }

      # eg: on_failed { ... }
      define_method(:"on_#{s}") do |&block|
        raise ArgumentError, "a block is required" unless block

        block.call(self) if send(:"#{s}?")
        self
      end
    end

    def good?
      !failed?
    end

    def on_good(&)
      raise ArgumentError, "a block is required" unless block_given?

      yield(self) if good?
      self
    end

    def bad?
      !success?
    end

    def on_bad(&)
      raise ArgumentError, "a block is required" unless block_given?

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

      run.results.reverse.find(&:failed?)
    end

    def caused_failure?
      return false unless failed?

      caused_failure == self
    end

    def threw_failure
      return unless failed?

      results = run.results.select(&:failed?)
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
      run.index(self)
    end

    def outcome
      initialized? || thrown_failure? ? state : status
    end

    def runtime(&block)
      return @runtime unless block_given?

      timeout_type = is_a?(Batch) ? :batch_timeout : :task_timeout
      timeout_secs = task.task_setting(timeout_type)

      Timeout.timeout(timeout_secs, TimeoutError, "execution exceeded #{timeout_secs} seconds") do
        @runtime = Utils::MonotonicRuntime.call(&block)
      end
    end

    def to_h
      ResultSerializer.call(self)
    end

    def to_s
      ResultInspector.call(to_h)
    end

  end
end
