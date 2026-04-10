# frozen_string_literal: true

module CMDx

  # @rbs Error: Class
  Error = Class.new(StandardError)
  Exception = Error

  # @rbs CoercionError: Class
  CoercionError = Class.new(Error)

  # @rbs DeprecationError: Class
  DeprecationError = Class.new(Error)

  # @rbs MiddlewareError: Class
  MiddlewareError = Class.new(Error)

  # @rbs UndefinedMethodError: Class
  UndefinedMethodError = Class.new(Error)

  # @rbs ValidationError: Class
  ValidationError = Class.new(Error)

end
