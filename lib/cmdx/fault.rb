# frozen_string_literal: true

module CMDx
  # Exception raised by `execute!` (strict mode) when a task fails. Carries
  # the originating {Result} (deepest in any propagation chain) and exposes
  # `task`, `signal`, `context`, and `chain` as delegators. The backtrace is
  # cleaned through the configured `backtrace_cleaner` when present.
  #
  # Use {.for?} or {.matches?} to build matcher subclasses suitable for
  # `rescue` clauses.
  class Fault < Error

    class << self

      # Returns a matcher subclass that matches Faults whose `task` is (or
      # inherits from) any of the given task classes. Suitable for use in
      # `rescue`.
      #
      # @param tasks [Array<Class>] one or more Task classes
      # @return [Class<Fault>] anonymous matcher subclass
      # @raise [ArgumentError] when no tasks are given
      #
      # @example
      #   rescue Fault.for?(ProcessOrder, ChargeCard) => fault
      #     Alert.for_fault(fault)
      #   end
      def for?(*tasks)
        tasks = tasks.flatten
        raise ArgumentError, "at least one task required" if tasks.empty?

        matcher do |other|
          tasks.any? { |task| other.task <= task }
        end
      end

      # Returns a matcher subclass that matches Faults whose `result.reason`
      # is equal to the given string. Suitable for use in `rescue`.
      #
      # @param reason [String] the reason to match
      # @return [Class<Fault>] anonymous matcher subclass
      # @raise [ArgumentError] when no reason is given
      #
      # @example
      #   rescue Fault.reason?("Payment failed") => fault
      #     Alert.for_fault(fault)
      #   end
      def reason?(reason)
        raise ArgumentError, "reason required" unless reason

        matcher do |other|
          other.result.reason == reason
        end
      end

      # Returns a matcher subclass whose `===` runs `block` against the fault.
      #
      # @yieldparam fault [Fault]
      # @yieldreturn [Boolean]
      # @return [Class<Fault>] anonymous matcher subclass
      # @raise [ArgumentError] when no block is given
      def matches?(&block)
        raise ArgumentError, "block required" unless block

        matcher(&block)
      end

      private

      def matcher(&)
        fault_class = self
        Class.new(fault_class) do
          define_singleton_method(:===) do |other|
            fault_class === other && yield(other)
          end
        end
      end

    end

    attr_reader :result

    # @param result [Result] the failed result this Fault represents
    def initialize(result)
      @result = result

      super(I18nProxy.tr(result.reason))

      if (frames = result.backtrace || result.cause&.backtrace_locations)
        frames = frames.map(&:to_s)
        frames = task.settings.backtrace_cleaner&.call(frames) || frames
        set_backtrace(frames)
      end
    end

    # @return [Class<Task>] the failing task class
    def task
      @result.task
    end

    # @return [Context] the failed task's context
    def context
      @result.context
    end

    # @return [Chain] the chain the failed result belongs to
    def chain
      @result.chain
    end

  end
end
