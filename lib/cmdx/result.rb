# frozen_string_literal: true

module CMDx
  # Immutable snapshot of a task execution result.
  # Built once by the Runtime after execution completes, then frozen.
  class Result

    # @rbs STATES: Array[String]
    STATES = %w[initialized executing complete interrupted].freeze

    # @rbs STATUSES: Array[String]
    STATUSES = %w[success skipped failed].freeze

    # Identity
    #
    # @return [String]
    attr_reader :task_id

    # @return [Class]
    attr_reader :task_class

    # @return [String]
    attr_reader :task_type

    # @return [Array<Symbol>]
    attr_reader :task_tags

    # Execution data
    #
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

    # Associated objects
    #
    # @return [Context]
    attr_reader :context

    # @return [Chain]
    attr_reader :chain

    # @return [Errors]
    attr_reader :errors

    # @return [Integer, nil] position in the chain
    attr_reader :index

    # @rbs (**untyped attrs) -> void
    def initialize(**attrs)
      attrs.each { |k, v| instance_variable_set(:"@#{k}", v) }
      freeze
    end

    # State queries

    # @rbs () -> bool
    def complete?
      state == "complete"
    end

    # @rbs () -> bool
    def interrupted?
      state == "interrupted"
    end

    # @rbs () -> bool
    def executed?
      complete? || interrupted?
    end

    # Status queries

    # @rbs () -> bool
    def success?
      status == "success"
    end

    # @rbs () -> bool
    def skipped?
      status == "skipped"
    end

    # @rbs () -> bool
    def failed?
      status == "failed"
    end

    # Compound queries

    # @rbs () -> bool
    def good?
      success?
    end
    alias ok? good?

    # @rbs () -> bool
    def bad?
      !good?
    end

    # @rbs () -> bool
    def strict?
      !!strict
    end

    # @rbs () -> bool
    def retried?
      retries.positive?
    end

    # @rbs () -> bool
    def rolled_back?
      !!rolled_back
    end

    # @rbs () -> bool
    def dry_run?
      chain&.dry_run? || false
    end

    # Chain analysis

    # @return [Result, nil] the first failed result in the chain that is strict
    #
    # @rbs () -> Result?
    def caused_failure
      return unless chain

      chain.results.find { |r| r.failed? && r.strict? }
    end

    # @rbs () -> bool
    def caused_failure?
      !caused_failure.nil?
    end

    # @return [Result, nil] the result that was thrown into this execution
    #
    # @rbs () -> Result?
    def threw_failure
      return unless chain && metadata

      thrown_id = metadata[:thrown_from]
      return unless thrown_id

      chain.results.find { |r| r.task_id == thrown_id }
    end

    # @rbs () -> bool
    def threw_failure?
      !threw_failure.nil?
    end

    # @rbs () -> bool
    def thrown_failure?
      threw_failure?
    end

    # @return [String] human-readable outcome label
    #
    # @rbs () -> String
    def outcome
      return "success" if success?
      return "skipped" if skipped?

      "failed"
    end

    # Handlers

    # Yields the block if the result matches one of the given states or statuses.
    #
    # @param filters [Array<String, Symbol>] states or statuses to match
    #
    # @return [Object, nil] the block result or nil
    #
    # @rbs (*(String | Symbol) filters) { (Result) -> untyped } -> untyped
    def on(*filters, &)
      matched = filters.any? do |f|
        f = f.to_s
        f == state || f == status
      end
      yield(self) if matched
    end

    # Pattern matching

    # @rbs () -> Array[untyped]
    def deconstruct
      [state, status, reason]
    end

    # @rbs (?Array[Symbol]? keys) -> Hash[Symbol, untyped]
    def deconstruct_keys(keys = nil)
      h = to_h
      keys ? h.slice(*keys) : h
    end

    # Serialization

    # @rbs () -> Hash[Symbol, untyped]
    def to_h
      {
        task_id:, task_class: task_class&.name, task_type:, task_tags:,
        state:, status:, reason:, metadata:,
        strict:, retries:, rolled_back:,
        index:, errors: errors&.to_h
      }
    end

    # @rbs () -> String
    def to_s
      parts = ["[#{status.upcase}]", task_class&.name || "anonymous"]
      parts << "(#{reason})" if reason
      parts.join(" ")
    end

  end
end
