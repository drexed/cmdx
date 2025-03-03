# frozen_string_literal: true

module CMDx

  # Base of all CMDx errors
  Error = Class.new(StandardError)

  # Raised when value could not be coerced to defined type
  CoercionError = Class.new(Error)

  # Raised when call execution time exceeds max allowed
  TimeoutError = Class.new(Interrupt)

  # Raised when call method not defined in implementing class
  UndefinedCallError = Class.new(Error)

  # Raised when unknown coercion type
  UnknownCoercionError = Class.new(Error)

  # Raised when value failed a validation
  ValidationError = Class.new(Error)

end
