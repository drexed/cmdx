# frozen_string_literal: true

module CMDx

  ##
  # Base exception class for all CMDx-specific errors.
  # All other CMDx exceptions inherit from this class, providing a common
  # hierarchy for error handling and rescue operations.
  #
  # This allows for catching all CMDx-related exceptions with a single rescue clause
  # while still maintaining specific error types for detailed error handling.
  #
  # @example Catching all CMDx errors
  #   begin
  #     ProcessOrderTask.call(invalid_params)
  #   rescue CMDx::Error => e
  #     logger.error "CMDx error occurred: #{e.message}"
  #   end
  #
  # @example Specific error handling
  #   begin
  #     ProcessOrderTask.call(order_id: "invalid")
  #   rescue CMDx::CoercionError => e
  #     # Handle type coercion failures
  #   rescue CMDx::ValidationError => e
  #     # Handle validation failures
  #   rescue CMDx::Error => e
  #     # Handle any other CMDx errors
  #   end
  #
  # @see StandardError Ruby's standard error base class
  # @since 1.0.0
  Error = Class.new(StandardError)

  ##
  # Raised when a value cannot be coerced to the specified type.
  # This exception occurs during parameter processing when type coercion fails,
  # typically due to incompatible data formats or invalid input values.
  #
  # CoercionError is raised by the various coercion modules when they encounter
  # values that cannot be converted to the target type. Each coercion module
  # provides specific error messages indicating the expected type and the
  # problematic value.
  #
  # @example Integer coercion failure
  #   class MyTask < CMDx::Task
  #     required :count, type: :integer
  #   end
  #
  #   # This will raise CoercionError during parameter processing
  #   MyTask.call(count: "not_a_number")
  #   # => CMDx::CoercionError: could not coerce into an integer
  #
  # @example Date coercion failure
  #   class ScheduleTask < CMDx::Task
  #     required :due_date, type: :date
  #   end
  #
  #   ScheduleTask.call(due_date: "invalid_date")
  #   # => CMDx::CoercionError: could not coerce into a date
  #
  # @example Handling coercion errors
  #   begin
  #     MyTask.call(count: "invalid")
  #   rescue CMDx::CoercionError => e
  #     # Log the coercion failure and provide user-friendly message
  #     logger.warn "Invalid input format: #{e.message}"
  #     render json: { error: "Please provide a valid number" }
  #   end
  #
  # @see Parameter Parameter type definitions and coercion
  # @see ParameterValue Parameter value processing and coercion
  # @since 1.0.0
  CoercionError = Class.new(Error)

  ##
  # Raised when a task class doesn't implement the required `call` method.
  # This exception enforces the CMDx contract that all task classes must
  # provide a `call` method containing their business logic.
  #
  # This error typically occurs during development when creating new task
  # classes that inherit from CMDx::Task but forget to implement the
  # abstract `call` method.
  #
  # @example Missing call method
  #   class IncompleteTask < CMDx::Task
  #     required :data, type: :string
  #     # Missing call method implementation
  #   end
  #
  #   IncompleteTask.call(data: "test")
  #   # => CMDx::UndefinedCallError: call method not defined in IncompleteTask
  #
  # @example Proper task implementation
  #   class CompleteTask < CMDx::Task
  #     required :data, type: :string
  #
  #     def call
  #       # Business logic implementation
  #       context.result = process(data)
  #     end
  #   end
  #
  # @example Handling undefined call errors
  #   begin
  #     SomeTask.call(params)
  #   rescue CMDx::UndefinedCallError => e
  #     # This should typically only happen during development
  #     logger.error "Task implementation incomplete: #{e.message}"
  #     raise # Re-raise as this is a programming error
  #   end
  #
  # @see Task Task base class and call method requirement
  # @see Workflow Workflow base class and call method requirement
  # @since 1.0.0
  UndefinedCallError = Class.new(Error)

  ##
  # Raised when an unknown or unsupported coercion type is specified.
  # This exception occurs when parameter definitions reference type coercions
  # that don't exist or aren't registered in the CMDx coercion system.
  #
  # This error helps catch typos in type specifications and ensures that
  # only supported data types are used in parameter definitions.
  #
  # @example Unknown type specification
  #   class MyTask < CMDx::Task
  #     required :value, type: :unknown_type  # Typo or unsupported type
  #   end
  #
  #   MyTask.call(value: "test")
  #   # => CMDx::UnknownCoercionError: unknown coercion unknown_type
  #
  # @example Common typos
  #   class TaskWithTypo < CMDx::Task
  #     required :count, type: :integr      # Should be :integer
  #     required :flag, type: :bool         # Should be :boolean
  #     required :data, type: :json         # Should be :hash
  #   end
  #
  # @example Supported types
  #   class ProperTask < CMDx::Task
  #     required :id, type: :integer
  #     required :active, type: :boolean
  #     required :metadata, type: :hash
  #     required :tags, type: :array
  #     required :name, type: :string
  #     required :score, type: :float
  #     required :created_at, type: :date_time
  #   end
  #
  # @example Handling unknown coercion errors
  #   begin
  #     MyTask.call(params)
  #   rescue CMDx::UnknownCoercionError => e
  #     # This indicates a programming error in parameter definition
  #     logger.error "Invalid type specification: #{e.message}"
  #     raise # Re-raise as this should be fixed in code
  #   end
  #
  # @see Parameter Parameter type definitions
  # @see ParameterValue Type coercion processing
  # @since 1.0.0
  UnknownCoercionError = Class.new(Error)

  ##
  # Raised when an unknown or unsupported validator type is specified.
  # This exception occurs when parameter definitions reference validators
  # that don't exist or aren't registered in the CMDx validator system.
  #
  # This error helps catch typos in validator specifications and ensures that
  # only supported validators are used in parameter definitions.
  #
  # @example Unknown validator specification
  #   class MyTask < CMDx::Task
  #     required :value, unknown_validator: true  # Typo or unsupported validator
  #   end
  #
  #   MyTask.call(value: "test")
  #   # => CMDx::UnknownValidatorError: unknown validator unknown_validator
  #
  # @example Common typos
  #   class TaskWithTypo < CMDx::Task
  #     required :email, presense: true     # Should be :presence
  #     required :count, numerc: { min: 0 } # Should be :numeric
  #     required :name, lenght: { max: 50 } # Should be :length
  #   end
  #
  # @example Supported validators
  #   class ProperTask < CMDx::Task
  #     required :email, presence: true, format: { with: /@/ }
  #     required :count, numeric: { min: 0, max: 100 }
  #     required :name, length: { max: 50 }
  #     required :status, inclusion: { in: %w[active inactive] }
  #   end
  #
  # @example Handling unknown validator errors
  #   begin
  #     MyTask.call(params)
  #   rescue CMDx::UnknownValidatorError => e
  #     # This indicates a programming error in parameter definition
  #     logger.error "Invalid validator specification: #{e.message}"
  #     raise # Re-raise as this should be fixed in code
  #   end
  #
  # @see Parameter Parameter validation definitions
  # @see ParameterValue Validation processing
  # @since 1.1.0
  UnknownValidatorError = Class.new(Error)

  ##
  # Raised when a parameter value fails validation rules.
  # This exception occurs during parameter processing when values don't meet
  # the specified validation criteria, such as format requirements, length
  # constraints, or custom validation logic.
  #
  # ValidationError provides detailed feedback about why validation failed,
  # helping developers and users understand what corrections are needed.
  #
  # @example Presence validation failure
  #   class CreateUserTask < CMDx::Task
  #     required :email, type: :string, presence: true
  #   end
  #
  #   CreateUserTask.call(email: "")
  #   # => CMDx::ValidationError: cannot be empty
  #
  # @example Format validation failure
  #   class ValidateEmailTask < CMDx::Task
  #     required :email, type: :string, format: { with: /@/ }
  #   end
  #
  #   ValidateEmailTask.call(email: "invalid-email")
  #   # => CMDx::ValidationError: is an invalid format
  #
  # @example Length validation failure
  #   class SetPasswordTask < CMDx::Task
  #     required :password, type: :string, length: { min: 8 }
  #   end
  #
  #   SetPasswordTask.call(password: "short")
  #   # => CMDx::ValidationError: length must be at least 8
  #
  # @example Custom validation failure
  #   class ProcessOrderTask < CMDx::Task
  #     required :quantity, type: :integer, custom: -> (val) { val > 0 }
  #   end
  #
  #   ProcessOrderTask.call(quantity: -1)
  #   # => CMDx::ValidationError: is not valid
  #
  # @example Handling validation errors
  #   begin
  #     CreateUserTask.call(email: "", password: "short")
  #   rescue CMDx::ValidationError => e
  #     # Provide user-friendly feedback
  #     render json: {
  #       error: "Validation failed",
  #       message: e.message,
  #       field: extract_field_from_context(e)
  #     }
  #   end
  #
  # @see Parameter Parameter validation options
  # @see ParameterValue Validation processing
  # @see Validators Validation modules (Presence, Format, Length, etc.)
  # @since 1.0.0
  ValidationError = Class.new(Error)

end
