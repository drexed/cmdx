# frozen_string_literal: true

module CMDx

  Error = Class.new(StandardError)

  CoercionError = Class.new(Error)

  UndefinedCallError = Class.new(Error)

  UnknownCallbackError = Class.new(Error)

  UnknownCoercionError = Class.new(Error)

  UnknownValidatorError = Class.new(Error)

  ValidationError = Class.new(Error)

end
