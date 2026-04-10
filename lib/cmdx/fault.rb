# frozen_string_literal: true

module CMDx

  # Base class for control flow interruptions surfaced by execute! (bang variant).
  # Carries the frozen Result so callers can inspect execution state.
  class Fault < Error

    # @return [Result] the result that triggered the fault
    #
    # @rbs @result: Result
    attr_reader :result

    # @param result [Result] the completed result
    #
    # @rbs (Result result) -> void
    def initialize(result)
      @result = result
      super(result.reason || Locale.t("cmdx.reasons.unspecified"))
    end

    # @rbs () -> Hash[Symbol, untyped]
    def to_h
      result.to_h
    end

    # @rbs () -> String
    def to_s
      result.to_s
    end

  end

  # Raised by execute! when a task fails.
  class FailFault < Fault; end

  # Raised by execute! when a task is skipped.
  class SkipFault < Fault; end

end
