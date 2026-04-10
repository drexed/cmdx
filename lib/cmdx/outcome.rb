# frozen_string_literal: true

module CMDx
  # Mutable execution outcome for a single run. Transitions are explicit.
  class Outcome

    STATES = %i[initialized executing complete interrupted].freeze
    STATUSES = %i[success skipped failed].freeze

    # Internal +catch+ tag for early exit from +work+.
    HALT_TAG = :cmdx_v2_halt

    # @return [Symbol]
    attr_reader :state

    # @return [Symbol]
    attr_reader :status

    # @return [String, nil]
    attr_reader :reason

    # @return [Exception, nil]
    attr_reader :cause

    # @return [Hash{Symbol => Object}]
    attr_reader :metadata

    # @return [Integer]
    attr_accessor :retries

    # @return [Boolean]
    attr_accessor :rolled_back

    # @return [Boolean]
    def rolled_back?
      !!@rolled_back
    end

    def initialize
      @state = :initialized
      @status = :success
      @reason = nil
      @cause = nil
      @metadata = {}
      @retries = 0
      @rolled_back = false
    end

    STATES.each do |s|
      define_method(:"#{s}?") { @state == s }
    end

    STATUSES.each do |s|
      define_method(:"#{s}?") { @status == s }
    end

    # @return [Boolean]
    def executed?
      complete? || interrupted?
    end

    # @return [Boolean]
    def good?
      !failed?
    end

    alias ok? good?

    # @return [Boolean]
    def bad?
      !success?
    end

    # @return [void]
    def executing!
      return if executing?

      raise "invalid state #{@state}" unless initialized?

      @state = :executing
    end

    # @return [void]
    def complete!
      return if complete?

      raise "invalid state #{@state}" unless executing?

      @state = :complete
    end

    # @return [void]
    def interrupt!
      return if interrupted?

      raise "invalid state #{@state}" if complete?

      @state = :interrupted
    end

    # @param reason [String, nil]
    # @param halt [Boolean]
    # @param metadata [Hash]
    # @return [void]
    def success!(reason = nil, halt: true, **metadata)
      raise "invalid status #{@status}" unless success?

      @reason = reason if reason
      merge_metadata!(metadata)
      throw(HALT_TAG) if halt
    end

    # @param reason [String, nil]
    # @param halt [Boolean]
    # @param cause [Exception, nil]
    # @param metadata [Hash]
    # @return [void]
    def skip!(reason = nil, halt: true, cause: nil, **metadata)
      return if skipped?

      raise "invalid status #{@status}" unless success?

      @state = :interrupted
      @status = :skipped
      @reason = reason || "Unspecified"
      @cause = cause
      merge_metadata!(metadata)
      throw(HALT_TAG) if halt
    end

    # @param reason [String, nil]
    # @param halt [Boolean]
    # @param cause [Exception, nil]
    # @param metadata [Hash]
    # @return [void]
    def fail!(reason = nil, halt: true, cause: nil, **metadata)
      return if failed?

      raise "invalid status #{@status}" unless success?

      @state = :interrupted
      @status = :failed
      @reason = reason || "Unspecified"
      @cause = cause
      merge_metadata!(metadata)
      throw(HALT_TAG) if halt
    end

    # @param other [Outcome]
    # @param cause [Exception, nil]
    # @param halt [Boolean]
    # @param extra [Hash]
    # @return [void]
    def propagate_from!(other, cause: nil, halt: true, **extra)
      @state = other.state
      @status = other.status
      @reason = other.reason
      @cause = cause || other.cause
      merge_metadata!(other.metadata.merge(extra))
      throw(HALT_TAG) if halt
    end

    # @param hash [Hash{Symbol => Object}]
    # @return [void]
    def merge_metadata!(hash)
      @metadata.merge!(hash)
    end

    # @return [void]
    def executed!
      success? ? complete! : interrupt!
    end

    # @return [self]
    def freeze
      @metadata.freeze
      super
    end

  end
end
