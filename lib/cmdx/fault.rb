# frozen_string_literal: true

module CMDx

  # Base fault class. Faults carry the Result of a failed/skipped execution.
  class Fault < Error

    # @return [Result, nil]
    attr_reader :result

    # @param message [String]
    # @param result [Result, nil]
    #
    # @rbs (String message, ?result: Result?) -> void
    def initialize(message = nil, result: nil)
      @result = result
      super(message || result&.reason)
    end

    # Returns true when +klass+ is in the exception class hierarchy OR
    # when it matches the cause chain of the wrapped result.
    #
    # @rbs (untyped other) -> bool
    def self.===(other)
      return true if super

      other.is_a?(Fault) && other.result&.cause.is_a?(self)
    end

  end

  # Raised by execute! on failure.
  class FailFault < Fault; end

  # Raised by execute! on skip.
  class SkipFault < Fault; end

  # Raised by the Timeout middleware.
  #
  # @rbs TimeoutError: Class
  TimeoutError = Class.new(Interrupt)

end
