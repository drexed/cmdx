# frozen_string_literal: true

module CMDx
  # Frozen immutable snapshot of a task execution.
  # Built from Session data after execution completes. Always frozen.
  class Result

    STATES = %w[initialized executing complete interrupted].freeze
    STATUSES = %w[success skipped failed].freeze

    # @return [String]
    attr_reader :task_id

    # @return [String]
    attr_reader :task_class

    # @return [String]
    attr_reader :task_type

    # @return [Array<String>]
    attr_reader :task_tags

    # @return [String]
    attr_reader :state

    # @return [String]
    attr_reader :status

    # @return [String, nil]
    attr_reader :reason

    # @return [Exception, nil]
    attr_reader :cause

    # @return [Hash]
    attr_reader :metadata

    # @return [Boolean]
    attr_reader :strict

    # @return [Integer]
    attr_reader :retries

    # @return [Boolean]
    attr_reader :rolled_back

    # @return [Context]
    attr_reader :context

    # @return [Chain, nil]
    attr_reader :chain

    # @return [Errors]
    attr_reader :errors

    # @return [String, nil]
    attr_reader :trace_id

    # @return [Integer]
    attr_reader :index

    # @param task_id [String]
    # @param task_class [Class]
    # @param outcome [Outcome]
    # @param context [Context]
    # @param errors [Errors]
    # @param chain [Chain, nil]
    # @param trace_id [String, nil]
    # @param tags [Array]
    # @param index [Integer]
    #
    # @rbs (task_id: String, task_class: Class, outcome: Outcome, context: Context, errors: Errors, ?chain: Chain?, ?trace_id: String?, ?tags: Array[String], ?index: Integer) -> void
    def initialize(task_id:, task_class:, outcome:, context:, errors:, chain: nil, trace_id: nil, tags: [], index: 0) # rubocop:disable Metrics/ParameterLists
      @task_id = task_id
      @task_class = task_class.name || task_class.to_s
      @task_type = Utils::Format.type_name(task_class)
      @task_tags = tags
      @state = outcome.state.to_s
      @status = outcome.status.to_s
      @reason = outcome.reason
      @cause = outcome.cause
      @metadata = outcome.metadata.dup
      @strict = @metadata.delete(:strict) { true }
      @retries = outcome.retries
      @rolled_back = outcome.rolled_back?
      @context = context
      @chain = chain
      @errors = errors
      @trace_id = trace_id
      @index = index
      freeze
    end

    # @return [Boolean]
    # @rbs () -> bool
    def success?
      @status == "success"
    end

    # @return [Boolean]
    # @rbs () -> bool
    def failed?
      @status == "failed"
    end

    # @return [Boolean]
    # @rbs () -> bool
    def skipped?
      @status == "skipped"
    end

    # @return [Boolean]
    # @rbs () -> bool
    def good?
      !failed?
    end
    alias ok? good?

    # @return [Boolean]
    # @rbs () -> bool
    def bad?
      !success?
    end

    # @return [Boolean]
    # @rbs () -> bool
    def strict?
      !!@strict
    end

    # @return [Boolean]
    # @rbs () -> bool
    def complete?
      @state == "complete"
    end

    # @return [Boolean]
    # @rbs () -> bool
    def interrupted?
      @state == "interrupted"
    end

    # @return [Boolean]
    # @rbs () -> bool
    def executed?
      complete? || interrupted?
    end

    # @return [Boolean]
    # @rbs () -> bool
    def retried?
      @retries.positive?
    end

    # @return [Boolean]
    # @rbs () -> bool
    def rolled_back?
      !!@rolled_back
    end

    # @return [Boolean]
    # @rbs () -> bool
    def dry_run?
      !!context[:dry_run]
    end

    # Yields to the block if any filter matches state or status.
    #
    # @param filters [Array<Symbol, String>]
    # @return [self]
    #
    # @rbs (*Symbol | String filters) { (Result) -> void } -> self
    def on(*filters, &block)
      matched = filters.any? { |f| [@state, @status].include?(f.to_s) }
      yield self if matched && block
      self
    end

    # First strict failure in the chain, if any.
    #
    # @return [Result, nil]
    #
    # @rbs () -> Result?
    def caused_failure
      return unless chain

      chain.results.find { |r| r.failed? && r.strict? && r != self }
    end

    # Result that was propagated via throw!, if any.
    #
    # @return [Result, nil]
    #
    # @rbs () -> Result?
    def threw_failure
      thrown_from = @metadata[:thrown_from]
      return unless thrown_from && chain

      chain.results.find { |r| r.task_id == thrown_from }
    end

    # Pattern matching support.
    #
    # @rbs (?Array[Symbol]? keys) -> Hash[Symbol, untyped]
    def deconstruct_keys(keys)
      h = { state: @state, status: @status, reason: @reason, task_class: @task_class,
            task_id: @task_id, metadata: @metadata, errors: @errors.to_h }
      keys ? h.slice(*keys) : h
    end

    # @return [Hash]
    #
    # @rbs () -> Hash[Symbol, untyped]
    def to_h
      {
        task_id: @task_id, task_class: @task_class, task_type: @task_type,
        task_tags: @task_tags, state: @state, status: @status, reason: @reason,
        metadata: @metadata, retries: @retries, rolled_back: @rolled_back,
        trace_id: @trace_id, index: @index, errors: @errors.to_h
      }
    end

    # @return [String]
    #
    # @rbs () -> String
    def to_s
      parts = ["[#{@task_class}]", "state=#{@state}", "status=#{@status}"]
      parts << "reason=#{@reason}" if @reason
      parts << "trace=#{@trace_id}" if @trace_id
      parts.join(" ")
    end

    # @return [String]
    #
    # @rbs () -> String
    def inspect
      "#<#{self.class} #{self}>"
    end

  end
end
