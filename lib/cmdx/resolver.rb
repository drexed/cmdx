# frozen_string_literal: true

module CMDx
  # Manages state transitions for a {CMDx::Result}, handling success annotation,
  # skipping, failure, throwing, and halting with fault raising.
  #
  # The Resolver owns the +strict+ flag and all transition logic. It writes to the
  # Result via +instance_variable_set+ so that Result remains a pure data object.
  #
  # @example Accessed through the task
  #   task.resolver.fail!("Validation failed", cause: validation_error)
  #   task.resolver.skip!("Already processed", halt: false)
  class Resolver

    extend Forwardable

    # Returns the result being resolved.
    #
    # @return [CMDx::Result] The result instance
    #
    # @rbs @result: Result
    attr_reader :result

    def_delegators :result, :task, :success?, :skipped?, :failed?,
                   :initialized?, :executing?, :complete?, :interrupted?

    # @param result [CMDx::Result] The result to manage transitions for
    #
    # @return [CMDx::Resolver] A new resolver instance
    #
    # @raise [TypeError] When result is not a CMDx::Result instance
    #
    # @example
    #   resolver = CMDx::Resolver.new(result)
    #
    # @rbs (Result) -> void
    def initialize(result)
      raise TypeError, "must be a CMDx::Result" unless result.is_a?(Result)

      @result = result
    end

    # Transitions the result to the appropriate final state based on status.
    # Delegates to {#complete!} when successful, {#interrupt!} otherwise.
    #
    # @return [void]
    #
    # @example
    #   resolver.executed!
    #
    # @rbs () -> void
    def executed!
      success? ? complete! : interrupt!
    end

    # Transitions the result state from initialized to executing.
    #
    # @raise [RuntimeError] When attempting to transition from invalid state
    #
    # @example
    #   resolver.executing!
    #
    # @rbs () -> void
    def executing!
      return if executing?

      raise "can only transition to #{Result::EXECUTING} from #{Result::INITIALIZED}" unless initialized?

      assign(state: Result::EXECUTING)
    end

    # Transitions the result state from executing to complete.
    #
    # @raise [RuntimeError] When attempting to transition from invalid state
    #
    # @example
    #   resolver.complete!
    #
    # @rbs () -> void
    def complete!
      return if complete?

      raise "can only transition to #{Result::COMPLETE} from #{Result::EXECUTING}" unless executing?

      assign(state: Result::COMPLETE)
    end

    # Transitions the result state to interrupted.
    #
    # @raise [RuntimeError] When attempting to transition from invalid state
    #
    # @example
    #   resolver.interrupt!
    #
    # @rbs () -> void
    def interrupt!
      return if interrupted?

      raise "cannot transition to #{Result::INTERRUPTED} from #{Result::COMPLETE}" if complete?

      assign(state: Result::INTERRUPTED)
    end

    # Sets a reason and optional metadata on a successful result without
    # changing its state or status. Useful for annotating why a task succeeded.
    # When halt is true, uses throw/catch to exit the work method early.
    #
    # @param reason [String, nil] Reason or note for the success
    # @param halt [Boolean] Whether to halt execution after success
    # @param metadata [Hash] Additional metadata about the success
    # @option metadata [Object] :* Any key-value pairs for additional metadata
    #
    # @raise [RuntimeError] When status is not success
    #
    # @example
    #   resolver.success!("Created 42 records")
    #   resolver.success!("Imported", halt: false, rows: 100)
    #
    # @rbs (?String? reason, halt: bool, **untyped metadata) -> void
    def success!(reason = nil, halt: true, **metadata)
      raise "can only be used while #{Result::SUCCESS}" unless success?

      assign(
        reason:,
        metadata:
      )

      throw(:cmdx_halt) if halt
    end

    # @param reason [String, nil] Reason for skipping the task
    # @param halt [Boolean] Whether to halt execution after skipping
    # @param cause [Exception, nil] Exception that caused the skip
    # @param strict [Boolean] Whether this skip is strict (default: true).
    # @param metadata [Hash] Additional metadata about the skip
    # @option metadata [Object] :* Any key-value pairs for additional metadata
    #
    # @raise [RuntimeError] When attempting to skip from invalid status
    #
    # @example
    #   resolver.skip!("Dependencies not met", cause: dependency_error)
    #   resolver.skip!("Already processed", halt: false)
    #   resolver.skip!("Optional step", strict: false)
    #
    # @rbs (?String? reason, halt: bool, cause: Exception?, strict: bool, **untyped metadata) -> void
    def skip!(reason = nil, halt: true, cause: nil, strict: true, **metadata)
      return if skipped?

      raise "can only transition to #{Result::SKIPPED} from #{Result::SUCCESS}" unless success?

      assign(
        state: Result::INTERRUPTED,
        status: Result::SKIPPED,
        reason: reason || Locale.t("cmdx.reasons.unspecified"),
        cause:,
        strict:,
        metadata:
      )

      halt! if halt
    end

    # @param reason [String, nil] Reason for task failure
    # @param halt [Boolean] Whether to halt execution after failure
    # @param cause [Exception, nil] Exception that caused the failure
    # @param strict [Boolean] Whether this failure is strict (default: true).
    # @param metadata [Hash] Additional metadata about the failure
    # @option metadata [Object] :* Any key-value pairs for additional metadata
    #
    # @raise [RuntimeError] When attempting to fail from invalid status
    #
    # @example
    #   resolver.fail!("Validation failed", cause: validation_error)
    #   resolver.fail!("Network timeout", halt: false, timeout: 30)
    #   resolver.fail!("Soft failure", strict: false)
    #
    # @rbs (?String? reason, halt: bool, cause: Exception?, strict: bool, **untyped metadata) -> void
    def fail!(reason = nil, halt: true, cause: nil, strict: true, **metadata)
      return if failed?

      raise "can only transition to #{Result::FAILED} from #{Result::SUCCESS}" unless success?

      assign(
        state: Result::INTERRUPTED,
        status: Result::FAILED,
        reason: reason || Locale.t("cmdx.reasons.unspecified"),
        cause:,
        strict:,
        metadata:
      )

      halt! if halt
    end

    # @raise [SkipFault] When task was skipped
    # @raise [FailFault] When task failed
    #
    # @example
    #   resolver.halt!
    #
    # @rbs () -> void
    def halt!
      return if success?

      klass = skipped? ? SkipFault : FailFault
      fault = klass.new(result)

      frames = caller_locations(3..-1)

      unless frames.empty?
        frames = frames.map(&:to_s)

        if (cleaner = task.class.settings.backtrace_cleaner)
          cleaner.call(frames)
        end

        fault.set_backtrace(frames)
      end

      raise(fault)
    end

    # @param other [CMDx::Result] Result to throw from current result
    # @param halt [Boolean] Whether to halt execution after throwing
    # @param cause [Exception, nil] Exception that caused the throw
    # @param metadata [Hash] Additional metadata to merge
    # @option metadata [Object] :* Any key-value pairs for additional metadata
    #
    # @raise [TypeError] When other is not a CMDx::Result instance
    #
    # @example
    #   other_result = OtherTask.execute
    #   resolver.throw!(other_result, cause: upstream_error)
    #
    # @rbs (Result other, halt: bool, cause: Exception?, **untyped metadata) -> void
    def throw!(other, halt: true, cause: nil, **metadata)
      raise TypeError, "must be a CMDx::Result" unless other.is_a?(Result)

      assign(
        state: other.state,
        status: other.status,
        reason: other.reason,
        cause: cause || other.cause,
        strict: other.strict?,
        metadata: other.metadata.merge(metadata)
      )

      halt! if halt
    end

    private

    # Writes attributes to the result via instance_variable_set.
    #
    # @param attrs [Hash] Attributes to assign to the result
    #
    # @rbs (**untyped attrs) -> void
    def assign(**attrs)
      attrs.each { |key, value| @result.instance_variable_set(:"@#{key}", value) }
    end

  end
end
