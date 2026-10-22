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
      # @note Each call allocates a new anonymous subclass. Hoist the matcher
      #   to module scope (`MY_FAULT = CMDx::Fault.for?(MyTask)`) when used
      #   on hot paths to avoid class allocation churn over time.
      #
      # @param tasks [Array<Class>] one or more Task classes
      # @return [Class<Fault>] anonymous matcher subclass
      # @raise [ArgumentError] when no tasks are given
      #
      # @example
      #   begin
      #     MyTask.execute!(ctx)
      #   rescue Fault.for?(ProcessOrder, ChargeCard) => fault
      #     Alert.for_fault(fault)
      #   end
      def for?(*tasks)
        tasks = tasks.flatten
        raise ArgumentError, "Fault.for? requires at least one Task class" if tasks.empty?

        matcher do |other|
          tasks.any? { |task| other.task <= task }
        end
      end

      # Returns a matcher subclass that matches Faults whose `result.reason`
      # is equal to the given string. Suitable for use in `rescue`.
      #
      # @note Each call allocates a new anonymous subclass. Hoist the matcher
      #   to module scope (`PAYMENT_FAULT = CMDx::Fault.reason?("Payment failed")`)
      #   when used on hot paths to avoid class allocation churn.
      #
      # @param reason [String] the reason to match
      # @return [Class<Fault>] anonymous matcher subclass
      # @raise [ArgumentError] when no reason is given
      #
      # @example
      #   begin
      #     MyTask.execute!(ctx)
      #   rescue Fault.reason?("Payment failed") => fault
      #     Alert.for_fault(fault)
      #   end
      def reason?(reason)
        raise ArgumentError, "Fault.reason? requires a reason" unless reason

        matcher do |other|
          other.result.reason == reason
        end
      end

      # Returns a matcher subclass whose `===` runs `block` against the fault.
      #
      # @note Each call allocates a new anonymous subclass. Hoist the matcher
      #   to module scope when used on hot paths to avoid class allocation
      #   churn.
      #
      # @param block [#call] `(fault) -> Boolean` matcher body
      # @yieldparam fault [Fault]
      # @yieldreturn [Boolean]
      # @return [Class<Fault>] anonymous matcher subclass
      # @raise [ArgumentError] when no block is given
      def matches?(&block)
        raise ArgumentError, "Fault.matches? requires a block" unless block

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

    # Enriches the stdlib detailed message with validation errors and
    # propagation context for IRB and other debug formatters. {#message} is
    # unchanged.
    #
    # @param highlight [Boolean] forwarded to `Exception#detailed_message`
    # @param order [Symbol] forwarded to `Exception#detailed_message`
    # @return [String]
    def detailed_message(highlight: true, order: :top)
      lines = [super]
      append_errors_lines(lines)
      append_origin_line(lines)
      lines.join("\n")
    end

    # @return [String] human-readable representation
    def inspect
      "#<#{self.class} task=#{task.name} tid=#{result.tid} cid=#{result.cid} xid=#{result.xid} reason=#{result.reason.inspect} errors=#{inspect_errors(result.errors)}>"
    end

    private

    # Stable across Ruby versions (Hash#inspect symbol-key style differs on 3.3).
    def inspect_errors(errors)
      pairs = errors.to_h.map { |key, messages| "#{key}: #{messages.inspect}" }
      "{#{pairs.join(', ')}}"
    end

    def append_errors_lines(lines)
      return if result.errors.empty?

      lines << "  errors:"
      result.errors.each do |key, messages|
        messages.each { |message| lines << "    #{key}: #{message}" }
      end
    end

    def append_origin_line(lines)
      origin = result.origin
      return unless origin

      reason = origin.reason || "no reason"
      lines << "  origin: #{origin.task.name} (#{reason})"
    end

  end
end
