# frozen_string_literal: true

module CMDx
  # Immutable execution outcome. Exposes state, status, context, metadata,
  # and chain information for every task execution.
  class Result

    STATES = %w[initialized executing complete interrupted].freeze
    STATUSES = %w[success skipped failed].freeze

    STATE_INITIALIZED = "initialized"
    STATE_EXECUTING   = "executing"
    STATE_COMPLETE    = "complete"
    STATE_INTERRUPTED = "interrupted"

    STATUS_SUCCESS = "success"
    STATUS_SKIPPED = "skipped"
    STATUS_FAILED  = "failed"

    HANDLER_MAP = {
      success: [STATUS_SUCCESS].freeze,
      skipped: [STATUS_SKIPPED].freeze,
      failed: [STATUS_FAILED].freeze,
      complete: [STATE_COMPLETE].freeze,
      interrupted: [STATE_INTERRUPTED].freeze,
      executed: [STATE_COMPLETE, STATE_INTERRUPTED].freeze,
      good: [STATUS_SUCCESS, STATUS_SKIPPED].freeze,
      ok: [STATUS_SUCCESS, STATUS_SKIPPED].freeze,
      bad: [STATUS_SKIPPED, STATUS_FAILED].freeze
    }.freeze

    attr_accessor :index, :chain
    attr_reader :task, :context, :state, :status, :reason, :cause, :metadata, :retries

    def initialize(task:, context:)
      @task = task
      @context = context
      @chain = nil
      @state = STATE_INITIALIZED
      @status = STATUS_SUCCESS
      @reason = nil
      @cause = nil
      @metadata = {}
      @index = 0
      @retries = 0
      @rolled_back = false
      @strict = false
    end

    # -- State predicates --

    # @return [Boolean]
    def initialized?
      @state == STATE_INITIALIZED
    end

    # @return [Boolean]
    def executing?
      @state == STATE_EXECUTING
    end

    # @return [Boolean]
    def complete?
      @state == STATE_COMPLETE
    end

    # @return [Boolean]
    def interrupted?
      @state == STATE_INTERRUPTED
    end

    # @return [Boolean] true if complete or interrupted
    def executed?
      complete? || interrupted?
    end

    # -- Status predicates --

    # @return [Boolean]
    def success?
      @status == STATUS_SUCCESS
    end

    # @return [Boolean]
    def skipped?
      @status == STATUS_SKIPPED
    end

    # @return [Boolean]
    def failed?
      @status == STATUS_FAILED
    end

    # @return [Boolean] true if success or skipped
    def good?
      success? || skipped?
    end
    alias ok? good?

    # @return [Boolean] true if skipped or failed
    def bad?
      skipped? || failed?
    end

    # @return [String] unified outcome
    def outcome
      complete? ? STATUS_SUCCESS : @status
    end

    # @return [Boolean]
    def strict?
      @strict
    end

    # @return [Boolean]
    def retried?
      @retries.positive?
    end

    # @return [Boolean]
    def rolled_back?
      @rolled_back
    end

    # @return [Boolean]
    def dry_run?
      !!context[:dry_run]
    end

    # -- State transitions (internal) --

    # @api private
    def transition_to_executing!
      @state = STATE_EXECUTING
    end

    # @api private
    def transition_to_complete!
      @state = STATE_COMPLETE
    end

    # @api private
    def transition_to_interrupted!
      @state = STATE_INTERRUPTED
    end

    # @api private
    def skip!(reason = nil, **meta)
      return if @status == STATUS_SKIPPED

      raise "Cannot transition from #{@status} to skipped" if @status != STATUS_SUCCESS

      @status = STATUS_SKIPPED
      @state = STATE_INTERRUPTED
      @reason = reason || Messages.resolve("halt.unspecified")
      @cause = SkipFault.new(@reason, result: self)
      @metadata.merge!(meta)
    end

    # @api private
    def fail!(reason = nil, **meta)
      return if @status == STATUS_FAILED

      raise "Cannot transition from #{@status} to failed" if @status != STATUS_SUCCESS

      @status = STATUS_FAILED
      @state = STATE_INTERRUPTED
      @reason = reason || Messages.resolve("halt.unspecified")
      @cause = FailFault.new(@reason, result: self)
      @metadata.merge!(meta)
    end

    # @api private
    def succeed!(reason = nil, **meta)
      raise "Cannot annotate success when status is #{@status}" unless @status == STATUS_SUCCESS

      @reason = reason
      @metadata.merge!(meta)
    end

    # @api private
    def fail_from_exception!(exception, backtrace_opt: false, backtrace_cleaner: nil)
      @status = STATUS_FAILED
      @state = STATE_INTERRUPTED
      @reason = "[#{exception.class}] #{exception.message}"
      @cause = exception

      return unless backtrace_opt && exception.respond_to?(:backtrace) && exception.backtrace

      bt = exception.backtrace
      bt = backtrace_cleaner.call(bt) if backtrace_cleaner
      @metadata[:backtrace] = bt
    end

    # @api private
    def throw!(other_result, **meta)
      raise TypeError, "Expected a CMDx::Result, got #{other_result.class}" unless other_result.is_a?(Result)
      return if other_result.success?

      @status = other_result.status
      @state = STATE_INTERRUPTED
      @reason = other_result.reason
      @cause = other_result.cause
      @metadata.merge!(meta)
      @metadata[:threw_from] = other_result.task&.class&.name
      @metadata[:caused_by] = other_result.metadata[:caused_by] || other_result.task&.class&.name
    end

    # @api private
    def increment_retries!
      @retries += 1
    end

    # @api private
    def mark_rolled_back!
      @rolled_back = true
    end

    # @api private
    def mark_strict!
      @strict = true
    end

    # @api private

    # -- Chain analysis --

    # @return [CMDx::Result, nil] the result that originally caused the failure
    def caused_failure
      return nil unless failed? && chain

      chain.results.find { |r| r.failed? && r.metadata[:caused_by].nil? && r != self }
    end

    # @return [CMDx::Result, nil] the result that threw/propagated the failure
    def threw_failure
      return nil unless failed? && metadata[:threw_from]

      chain&.results&.find { |r| r.task&.class&.name == metadata[:threw_from] }
    end

    # @return [Boolean]
    def caused_failure?
      failed? && metadata[:caused_by].nil? && metadata[:threw_from].nil?
    end

    # @return [Boolean]
    def threw_failure?
      failed? && metadata[:threw_from].present?
    rescue StandardError
      failed? && !metadata[:threw_from].nil?
    end

    # @return [Boolean]
    def thrown_failure?
      failed? && !metadata[:caused_by].nil?
    end

    # -- Handlers --

    # Chain handler for specific outcomes.
    #
    # @param type [Symbol] :success, :failed, :skipped, :complete, :interrupted, :executed, :good, :bad
    # @yield [self]
    # @return [self]
    def on(type, &block)
      raise ArgumentError, "on requires a block" unless block

      matchers = HANDLER_MAP.fetch(type) { raise ArgumentError, "Unknown handler type: #{type}" }

      yield(self) if matchers.include?(@state) || matchers.include?(@status)

      self
    end

    # -- Pattern matching --

    # @return [Array] [state, status, reason, metadata, context]
    def deconstruct
      [@state, @status, @reason, @metadata, @context]
    end

    # @return [Hash]
    def deconstruct_keys(keys)
      h = {
        state: @state, status: @status, reason: @reason,
        metadata: @metadata, context: @context,
        success: success?, failed: failed?, skipped: skipped?,
        good: good?, bad: bad?
      }
      keys ? h.slice(*keys) : h
    end

    def freeze
      @metadata.freeze
      super
    end

    def inspect
      "#<#{self.class} state=#{@state} status=#{@status} reason=#{@reason.inspect}>"
    end

  end
end
