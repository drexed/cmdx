# frozen_string_literal: true

module CMDx

  # Root error type for CMDx. Does not alias Ruby's +Exception+.
  class Error < StandardError
  end

  # Raised when attribute coercion fails.
  class CoercionError < Error
  end

  # Raised when a deprecated task is used (see {Deprecator}).
  class DeprecationError < Error
  end

  # Raised when +work+ is not implemented on a concrete task.
  class UndefinedMethodError < Error
  end

  # Raised when attribute validation fails in exception-raising mode.
  class ValidationError < Error
  end

  # Raised when execution exceeds a timeout budget (middleware).
  class TimeoutError < Interrupt
  end

end
