# frozen_string_literal: true

module CMDx
  class Result

    extend Forwardable

    STATES = [
      INITIALIZED = "initialized",  # Initial state before execution
      EXECUTING = "executing",      # Currently executing task logic
      COMPLETE = "complete",        # Successfully completed execution
      INTERRUPTED = "interrupted"   # Execution was halted due to failure
    ].freeze
    STATUSES = [
      SUCCESS = "success",  # Task completed successfully
      SKIPPED = "skipped",  # Task was skipped intentionally
      FAILED = "failed"     # Task failed due to error or validation
    ].freeze
    STRIP_FAILURE = proc do |hash, result, key|
      unless result.send(:"#{key}?")
        # Strip caused/threw failures since its the same info as the log line
        hash[key] = result.send(key).to_h.except(:caused_failure, :threw_failure)
      end
    end.freeze
    private_constant :STRIP_FAILURE

    attr_reader :task, :state, :status, :metadata, :reason, :cause

    def_delegators :task, :context, :chain

    def initialize(task)
      raise TypeError, "must be a Task or Workflow" unless task.is_a?(Task)

      @task = task
      @state = INITIALIZED
      @status = SUCCESS
      @metadata = {}
      @reason = nil
      @cause = nil
    end

    STATES.each do |s|
      define_method(:"#{s}?") { state == s }

      define_method(:"handle_#{s}") do |&block|
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

    def handle_executed(&)
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

    STATUSES.each do |s|
      define_method(:"#{s}?") { status == s }

      define_method(:"handle_#{s}") do |&block|
        raise ArgumentError, "block required" unless block

        block.call(self) if send(:"#{s}?")
        self
      end
    end

    def good?
      !failed?
    end

    def handle_good(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if good?
      self
    end

    def bad?
      !success?
    end

    def handle_bad(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if bad?
      self
    end

    def skip!(reason = nil, cause: nil, **metadata)
      return if skipped?

      raise "can only transition to #{SKIPPED} from #{SUCCESS}" unless success?

      @state = INTERRUPTED
      @status = SKIPPED
      @reason = reason || Locale.t("cmdx.faults.unspecified")
      @cause = cause
      @metadata = metadata

      halt! unless cause
    end

    def fail!(reason = nil, cause: nil, **metadata)
      return if failed?

      raise "can only transition to #{FAILED} from #{SUCCESS}" unless success?

      @state = INTERRUPTED
      @status = FAILED
      @reason = reason || Locale.t("cmdx.faults.unspecified")
      @cause = cause
      @metadata = metadata

      halt! unless cause
    end

    def halt!
      return if success?

      fault = Fault.build(self)
      # Strip the first two frames (this method and the delegator)
      fault.set_backtrace(caller_locations(3..-1))

      raise(fault)
    end

    def throw!(result, **metadata)
      raise TypeError, "must be a Result" unless result.is_a?(Result)

      metadatum = result.metadata.merge(metadata)

      if result.skipped?
        skip!(result.reason, cause: result.cause, **metadatum)
      elsif result.failed?
        fail!(result.reason, cause: result.cause, **metadatum)
      end
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

      current = index
      results = chain.results.select(&:failed?)
      results.find { |r| r.index > current } || results.last
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

    def to_h
      task.to_h.merge!(
        state:,
        status:,
        outcome:,
        metadata:
      ).tap do |hash|
        if interrupted?
          hash[:reason] = reason
          hash[:cause] = cause
        end

        if failed?
          STRIP_FAILURE.call(hash, self, :caused_failure)
          STRIP_FAILURE.call(hash, self, :threw_failure)
        end
      end
    end

    def to_s
      Utils::Format.to_str(to_h) do |key, value|
        case key
        when /failure/ then "#{key}=<[#{value[:index]}] #{value[:class]}: #{value[:id]}>"
        else "#{key}=#{value.inspect}"
        end
      end
    end

    def deconstruct(*)
      [state, status]
    end

    def deconstruct_keys(*)
      {
        state: state,
        status: status,
        metadata: metadata,
        executed: executed?,
        good: good?,
        bad: bad?
      }
    end

  end
end
