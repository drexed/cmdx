# frozen_string_literal: true

module CMDx
  # Parameter value resolution and processing class for CMDx tasks.
  #
  # The ParameterValue class handles the complete lifecycle of parameter value
  # processing including source resolution, type coercion, validation, and error
  # handling. It serves as the bridge between parameter definitions and their
  # actual values during task execution.
  #
  # @example Basic parameter value processing
  #   task = ProcessOrderTask.new
  #   parameter = Parameter.new(:order_id, klass: ProcessOrderTask, type: :integer)
  #   value_processor = ParameterValue.new(task, parameter)
  #   processed_value = value_processor.call  # Resolves, coerces, and validates
  #
  # @example Parameter value with validation
  #   parameter = Parameter.new(:email, klass: Task, type: :string,
  #                           format: { with: /@/ }, presence: true)
  #   value_processor = ParameterValue.new(task, parameter)
  #   value_processor.call  # Validates email format and presence
  #
  # @example Parameter value with default
  #   parameter = Parameter.new(:priority, klass: Task, default: "normal")
  #   value_processor = ParameterValue.new(task, parameter)
  #   value_processor.call  # Returns "normal" if not provided
  #
  # @see CMDx::Parameter Parameter definition and configuration
  # @see CMDx::Coercions Type coercion modules
  # @see CMDx::Validators Parameter validation modules
  class ParameterValue

    __cmdx_attr_delegator :parent, :method_source, :name, :options, :required?, :optional?, :type,
                          to: :parameter,
                          private: true

    # @return [CMDx::Task] The task instance being processed
    attr_reader :task

    # @return [CMDx::Parameter] The parameter definition being processed
    attr_reader :parameter

    # Initializes a new ParameterValue processor.
    #
    # Creates a parameter value processor for resolving, coercing, and validating
    # a specific parameter value within the context of a task instance.
    #
    # @param task [CMDx::Task] The task instance containing the parameter source
    # @param parameter [CMDx::Parameter] The parameter definition to process
    #
    # @example Creating a parameter value processor
    #   processor = ParameterValue.new(task_instance, parameter_definition)
    def initialize(task, parameter)
      @task      = task
      @parameter = parameter
    end

    # Processes the parameter value through coercion and validation.
    #
    # Executes the complete parameter value processing pipeline:
    # 1. Resolves the raw value from the source
    # 2. Applies type coercion based on parameter type
    # 3. Runs all configured validations
    # 4. Returns the final processed value
    #
    # @return [Object] The processed and validated parameter value
    # @raise [CoercionError] If type coercion fails
    # @raise [ValidationError] If validation fails
    #
    # @example Processing a simple parameter
    #   processor.call  # => 42 (after coercion and validation)
    #
    # @example Processing with validation failure
    #   processor.call  # => raises ValidationError: "is not valid"
    def call
      coerce!.tap { validate! }
    end

    private

    # Checks if the parameter source method is defined on the task.
    #
    # @return [Boolean] true if source method exists, false otherwise
    def source_defined?
      task.respond_to?(method_source, true) || task.__cmdx_try(method_source)
    end

    # Resolves the source object that contains the parameter value.
    #
    # Gets the source object by calling the method_source on the task instance.
    # Raises ValidationError if the source method is not defined.
    #
    # @return [Object] The source object containing parameter values
    # @raise [ValidationError] If source method is undefined
    def source
      return @source if defined?(@source)

      unless source_defined?
        raise ValidationError, I18n.t(
          "cmdx.parameters.undefined",
          default: "delegates to undefined method #{method_source}",
          source: method_source
        )
      end

      @source = task.__cmdx_try(method_source)
    end

    # Checks if the source object has the parameter value.
    #
    # @return [Boolean] true if source responds to parameter name, false otherwise
    def source_value?
      return false if source.nil?

      source.__cmdx_respond_to?(name, true)
    end

    # Checks if a required parameter value is missing from the source.
    #
    # @return [Boolean] true if required parameter is missing, false otherwise
    def source_value_required?
      return false if parent&.optional? && source.nil?

      required? && !source_value?
    end

    # Resolves the raw parameter value from the source.
    #
    # Gets the parameter value from the source object, handling required
    # parameter validation and default value resolution.
    #
    # @return [Object] The raw parameter value
    # @raise [ValidationError] If required parameter is missing
    def value
      return @value if defined?(@value)

      if source_value_required?
        raise ValidationError, I18n.t(
          "cmdx.parameters.required",
          default: "is a required parameter"
        )
      end

      @value = source.__cmdx_try(name)
      return @value unless @value.nil? && options.key?(:default)

      @value = task.__cmdx_yield(options[:default])
    end

    # Applies type coercion to the parameter value.
    #
    # Attempts to coerce the value to each specified type in order,
    # supporting multiple type fallbacks for flexible coercion.
    #
    # @return [Object] The coerced parameter value
    # @raise [CoercionError] If all coercion attempts fail
    # @raise [UnknownCoercionError] If an unknown type is specified
    def coerce!
      types = Array(type)
      tsize = types.size - 1

      types.each_with_index do |t, i|
        break CMDx.configuration.coercions.call(t, value, options)
      rescue CoercionError => e
        next if tsize != i

        raise(e) if tsize.zero?

        values = types.map(&:to_s).join(", ")
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_any",
          values:,
          default: "could not coerce into one of: #{values}"
        )
      end
    end

    # Checks if validations should be skipped for optional missing arguments.
    #
    # @return [Boolean] true if validations should be skipped, false otherwise
    def skip_validations_due_to_optional_missing_argument?
      optional? && value.nil? && !source.nil? && !source.__cmdx_respond_to?(name, true)
    end

    # Checks if a specific validator should be skipped due to conditional logic.
    #
    # @param key [Symbol] The validator key to check
    # @return [Boolean] true if validator should be skipped, false otherwise
    def skip_validator_due_to_conditional?(key)
      opts = options[key]
      opts.is_a?(Hash) && !task.__cmdx_eval(opts)
    end

    # Checks if a specific validator should be skipped due to allow_nil option.
    #
    # @param key [Symbol] The validator key to check
    # @return [Boolean] true if validator should be skipped, false otherwise
    def skip_validator_due_to_allow_nil?(key)
      opts = options[key]
      opts.is_a?(Hash) && opts[:allow_nil] && value.nil?
    end

    # Runs all configured validations on the parameter value.
    #
    # Iterates through all validation options and applies the appropriate
    # validators, respecting skip conditions for optional parameters,
    # conditional validations, and allow_nil settings.
    #
    # @return [void]
    # @raise [ValidationError] If any validation fails
    def validate!
      return if skip_validations_due_to_optional_missing_argument?

      options.each_key do |key|
        next if skip_validator_due_to_allow_nil?(key)
        next if skip_validator_due_to_conditional?(key)

        begin
          CMDx.configuration.validators.call(task, key, value, options)
        rescue UnknownValidatorError
          # Skip unknown validators (allows for custom option keys)
        end
      end
    end

  end
end
