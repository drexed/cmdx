# frozen_string_literal: true

module CMDx
  # Represents the execution result of a CMDx task, tracking state transitions,
  # status changes, and providing methods for handling different outcomes.
  #
  # The Result class manages the lifecycle of task execution from initialization
  # through completion or interruption, offering a fluent interface for status
  # checking and conditional handling.
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

    # @param task [CMDx::Task] The task instance this result represents
    #
    # @return [CMDx::Result] A new result instance for the task
    #
    # @raise [TypeError] When task is not a CMDx::Task instance
    #
    # @example
    #   result = CMDx::Result.new(my_task)
    #   result.state # => "initialized"
    def initialize(task)
      raise TypeError, "must be a CMDx::Task" unless task.is_a?(CMDx::Task)

      @task = task
      @state = INITIALIZED
      @status = SUCCESS
      @metadata = {}
      @reason = nil
      @cause = nil
    end

    STATES.each do |s|
      # @return [Boolean] Whether the result is in the specified state
      #
      # @example
      #   result.initialized? # => true
      #   result.executing?   # => false
      define_method(:"#{s}?") { state == s }

      # @param block [Proc] Block to execute conditionally
      #
      # @yield [self] Executes the block if result is in specified state
      #
      # @return [self] Returns self for method chaining
      #
      # @raise [ArgumentError] When no block is provided
      #
      # @example
      #   result.handle_initialized { |r| puts "Starting execution" }
      #   result.handle_complete { |r| puts "Task completed" }
      define_method(:"handle_#{s}") do |&block|
        raise ArgumentError, "block required" unless block

        block.call(self) if send(:"#{s}?")
        self
      end
    end

    # @return [self] Returns self for method chaining
    #
    # @example
    #   result.executed! # Transitions to complete or interrupted
    def executed!
      success? ? complete! : interrupt!
    end

    # @return [Boolean] Whether the task has been executed (complete or interrupted)
    #
    # @example
    #   result.executed? # => true if complete? || interrupted?
    def executed?
      complete? || interrupted?
    end

    # @param block [Proc] Block to execute conditionally
    #
    # @yield [self] Executes the block if task has been executed
    #
    # @return [self] Returns self for method chaining
    #
    # @raise [ArgumentError] When no block is provided
    #
    # @example
    #   result.handle_executed { |r| puts "Task finished: #{r.outcome}" }
    def handle_executed(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if executed?
      self
    end

    # @raise [RuntimeError] When attempting to transition from invalid state
    #
    # @example
    #   result.executing! # Transitions from initialized to executing
    def executing!
      return if executing?

      raise "can only transition to #{EXECUTING} from #{INITIALIZED}" unless initialized?

      @state = EXECUTING
    end

    # @raise [RuntimeError] When attempting to transition from invalid state
    #
    # @example
    #   result.complete! # Transitions from executing to complete
    def complete!
      return if complete?

      raise "can only transition to #{COMPLETE} from #{EXECUTING}" unless executing?

      @state = COMPLETE
    end

    # @raise [RuntimeError] When attempting to transition from invalid state
    #
    # @example
    #   result.interrupt! # Transitions from executing to interrupted
    def interrupt!
      return if interrupted?

      raise "cannot transition to #{INTERRUPTED} from #{COMPLETE}" if complete?

      @state = INTERRUPTED
    end

    STATUSES.each do |s|
      # @return [Boolean] Whether the result has the specified status
      #
      # @example
      #   result.success? # => true
      #   result.failed?  # => false
      define_method(:"#{s}?") { status == s }

      # @param block [Proc] Block to execute conditionally
      #
      # @yield [self] Executes the block if result has specified status
      #
      # @return [self] Returns self for method chaining
      #
      # @raise [ArgumentError] When no block is provided
      #
      # @example
      #   result.handle_success { |r| puts "Task succeeded" }
      #   result.handle_failed { |r| puts "Task failed: #{r.reason}" }
      define_method(:"handle_#{s}") do |&block|
        raise ArgumentError, "block required" unless block

        block.call(self) if send(:"#{s}?")
        self
      end
    end

    # @return [Boolean] Whether the task execution was successful (not failed)
    #
    # @example
    #   result.good? # => true if !failed?
    def good?
      !failed?
    end

    # @param block [Proc] Block to execute conditionally
    #
    # @yield [self] Executes the block if task execution was successful
    #
    # @return [self] Returns self for method chaining
    #
    # @raise [ArgumentError] When no block is provided
    #
    # @example
    #   result.handle_good { |r| puts "Task completed successfully" }
    def handle_good(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if good?
      self
    end

    # @return [Boolean] Whether the task execution was unsuccessful (not success)
    #
    # @example
    #   result.bad? # => true if !success?
    def bad?
      !success?
    end

    # @param block [Proc] Block to execute conditionally
    #
    # @yield [self] Executes the block if task execution was unsuccessful
    #
    # @return [self] Returns self for method chaining
    #
    # @raise [ArgumentError] When no block is provided
    #
    # @example
    #   result.handle_bad { |r| puts "Task had issues: #{r.reason}" }
    def handle_bad(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if bad?
      self
    end

    # @param reason [String, nil] Reason for skipping the task
    # @param halt [Boolean] Whether to halt execution after skipping
    # @param cause [Exception, nil] Exception that caused the skip
    # @param metadata [Hash] Additional metadata about the skip
    #
    # @raise [RuntimeError] When attempting to skip from invalid status
    #
    # @example
    #   result.skip!("Dependencies not met", cause: dependency_error)
    #   result.skip!("Already processed", halt: false)
    def skip!(reason = nil, halt: true, cause: nil, **metadata)
      return if skipped?

      raise "can only transition to #{SKIPPED} from #{SUCCESS}" unless success?

      @state = INTERRUPTED
      @status = SKIPPED
      @reason = reason || Locale.t("cmdx.faults.unspecified")
      @cause = cause
      @metadata = metadata

      halt! if halt
    end

    # @param reason [String, nil] Reason for task failure
    # @param halt [Boolean] Whether to halt execution after failure
    # @param cause [Exception, nil] Exception that caused the failure
    # @param metadata [Hash] Additional metadata about the failure
    #
    # @raise [RuntimeError] When attempting to fail from invalid status
    #
    # @example
    #   result.fail!("Validation failed", cause: validation_error)
    #   result.fail!("Network timeout", halt: false, timeout: 30)
    def fail!(reason = nil, halt: true, cause: nil, **metadata)
      return if failed?

      raise "can only transition to #{FAILED} from #{SUCCESS}" unless success?

      @state = INTERRUPTED
      @status = FAILED
      @reason = reason || Locale.t("cmdx.faults.unspecified")
      @cause = cause
      @metadata = metadata

      halt! if halt
    end

    # @raise [SkipFault] When task was skipped
    # @raise [FailFault] When task failed
    #
    # @example
    #   result.halt! # Raises appropriate fault based on status
    def halt!
      return if success?

      klass = skipped? ? SkipFault : FailFault
      fault = klass.new(self)

      # Strip the first two frames (this method and the delegator)
      frames = caller_locations(3..-1)
      fault.set_backtrace(frames) unless frames.empty?

      raise(fault)
    end

    # @param result [CMDx::Result] Result to throw from current result
    # @param halt [Boolean] Whether to halt execution after throwing
    # @param cause [Exception, nil] Exception that caused the throw
    # @param metadata [Hash] Additional metadata to merge
    #
    # @raise [TypeError] When result is not a CMDx::Result instance
    #
    # @example
    #   other_result = OtherTask.execute
    #   result.throw!(other_result, cause: upstream_error)
    def throw!(result, halt: true, cause: nil, **metadata)
      raise TypeError, "must be a CMDx::Result" unless result.is_a?(Result)

      @state = result.state
      @status = result.status
      @reason = result.reason
      @cause = cause || result.cause
      @metadata = result.metadata.merge(metadata)

      halt! if halt
    end

    # @return [CMDx::Result, nil] The result that caused this failure, or nil
    #
    # @example
    #   cause = result.caused_failure
    #   puts "Caused by: #{cause.task.id}" if cause
    def caused_failure
      return unless failed?

      chain.results.reverse.find(&:failed?)
    end

    # @return [Boolean] Whether this result caused the failure
    #
    # @example
    #   if result.caused_failure?
    #     puts "This task caused the failure"
    #   end
    def caused_failure?
      return false unless failed?

      caused_failure == self
    end

    # @return [CMDx::Result, nil] The result that threw this failure, or nil
    #
    # @example
    #   thrown = result.threw_failure
    #   puts "Thrown by: #{thrown.task.id}" if thrown
    def threw_failure
      return unless failed?

      current = index
      results = chain.results.select(&:failed?)
      results.find { |r| r.index > current } || results.last
    end

    # @return [Boolean] Whether this result threw the failure
    #
    # @example
    #   if result.threw_failure?
    #     puts "This task threw the failure"
    #   end
    def threw_failure?
      return false unless failed?

      threw_failure == self
    end

    # @return [Boolean] Whether this result is a thrown failure
    #
    # @example
    #   if result.thrown_failure?
    #     puts "This failure was thrown from another task"
    #   end
    def thrown_failure?
      failed? && !caused_failure?
    end

    # @return [Integer] Index of this result in the chain
    #
    # @example
    #   position = result.index
    #   puts "Task #{position + 1} of #{chain.results.count}"
    def index
      chain.index(self)
    end

    # @return [String] The outcome of the task execution
    #
    # @example
    #   result.outcome # => "success" or "interrupted"
    def outcome
      initialized? || thrown_failure? ? state : status
    end

    # @return [Hash] Hash representation of the result
    #
    # @example
    #   result.to_h
    #   # => {state: "complete", status: "success", outcome: "success", metadata: {}}
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
          STRIP_FAILURE.call(hash, self, :threw_failure)
          STRIP_FAILURE.call(hash, self, :caused_failure)
        end
      end
    end

    # @return [String] String representation of the result
    #
    # @example
    #   result.to_s # => "task_id=my_task state=complete status=success"
    def to_s
      Utils::Format.to_str(to_h) do |key, value|
        case key
        when /failure/ then "#{key}=<[#{value[:index]}] #{value[:class]}: #{value[:id]}>"
        else "#{key}=#{value.inspect}"
        end
      end
    end

    # @param keys [Array] Array of keys to deconstruct
    #
    # @return [Array] Array containing state and status
    #
    # @example
    #   state, status = result.deconstruct
    #   puts "State: #{state}, Status: #{status}"
    def deconstruct(*)
      [state, status]
    end

    # @param keys [Array] Array of keys to deconstruct
    #
    # @return [Hash] Hash with key-value pairs for pattern matching
    #
    # @example
    #   case result.deconstruct_keys
    #   in {state: "complete", good: true}
    #     puts "Task completed successfully"
    #   in {bad: true}
    #     puts "Task had issues"
    #   end
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
