# frozen_string_literal: true

module CMDx
  # Parameter evaluation system for task execution context.
  #
  # ParameterEvaluator processes parameter definitions by extracting values from
  # task context sources, applying type coercions, performing validations, and
  # handling optional parameters with default values. It ensures parameter values
  # meet the requirements defined in parameter specifications before task execution.
  class ParameterEvaluator

    cmdx_attr_delegator :parent, :method_source, :name, :options, :required?, :optional?, :type,
                        to: :parameter,
                        private: true

    # @return [CMDx::Task] The task instance being processed
    attr_reader :task

    # @return [CMDx::Parameter] The parameter definition being processed
    attr_reader :parameter

    # Creates a new parameter evaluator instance.
    #
    # @param task [CMDx::Task] the task instance containing parameter context
    # @param parameter [CMDx::Parameter] the parameter definition to evaluate
    #
    # @example Create evaluator for a task parameter
    #   evaluator = ParameterEvaluator.new(task, parameter)
    def initialize(task, parameter)
      @task      = task
      @parameter = parameter
    end

    # Evaluates a parameter by creating a new evaluator instance and calling it.
    #
    # @param task [CMDx::Task] the task instance containing parameter context
    # @param parameter [CMDx::Parameter] the parameter definition to evaluate
    #
    # @return [Object] the coerced and validated parameter value
    #
    # @raise [ValidationError] when parameter source is undefined or required parameter is missing
    # @raise [CoercionError] when parameter value cannot be coerced to expected type
    #
    # @example Evaluate a parameter value
    #   value = ParameterEvaluator.call(task, parameter)
    def self.call(task, parameter)
      new(task, parameter).call
    end

    # Evaluates the parameter by applying coercion and validation.
    #
    # @return [Object] the coerced and validated parameter value
    #
    # @raise [ValidationError] when parameter source is undefined or required parameter is missing
    # @raise [CoercionError] when parameter value cannot be coerced to expected type
    #
    # @example Evaluate parameter with coercion and validation
    #   evaluator = ParameterEvaluator.new(task, parameter)
    #   value = evaluator.call
    def call
      coerce!.tap { validate! }
    end

    private

    # Checks if the parameter source method is defined on the task.
    #
    # @return [Boolean] true if the source method exists, false otherwise
    #
    # @example Check if parameter source is defined
    #   evaluator.send(:source_defined?) #=> true
    def source_defined?
      task.respond_to?(method_source, true) || task.cmdx_try(method_source)
    end

    # Retrieves the parameter source object from the task.
    #
    # @return [Object] the source object containing parameter values
    #
    # @raise [ValidationError] when the source method is not defined on the task
    #
    # @example Get parameter source
    #   evaluator.send(:source) #=> #<Context:...>
    def source
      return @source if defined?(@source)

      unless source_defined?
        raise ValidationError, I18n.t(
          "cmdx.parameters.undefined",
          default: "delegates to undefined method #{method_source}",
          source: method_source
        )
      end

      @source = task.cmdx_try(method_source)
    end

    # Checks if the parameter value exists in the source object.
    #
    # @return [Boolean] true if the parameter value exists, false otherwise
    #
    # @example Check if parameter value exists
    #   evaluator.send(:source_value?) #=> true
    def source_value?
      return false if source.nil?

      source.cmdx_respond_to?(name, true)
    end

    # Checks if a required parameter value is missing from the source.
    #
    # @return [Boolean] true if required parameter is missing, false otherwise
    #
    # @example Check if required parameter is missing
    #   evaluator.send(:source_value_required?) #=> false
    def source_value_required?
      return false if parent&.optional? && source.nil?

      required? && !source_value?
    end

    # Extracts the parameter value from the source with default handling.
    #
    # @return [Object] the parameter value or default value
    #
    # @raise [ValidationError] when a required parameter is missing
    #
    # @example Get parameter value with default
    #   evaluator.send(:value) #=> "default_value"
    def value
      return @value if defined?(@value)

      if source_value_required?
        raise ValidationError, I18n.t(
          "cmdx.parameters.required",
          default: "is a required parameter"
        )
      end

      @value = source.cmdx_try(name)
      return @value unless @value.nil? && options.key?(:default)

      @value = task.cmdx_yield(options[:default])
    end

    # Applies type coercion to the parameter value.
    #
    # @return [Object] the coerced parameter value
    #
    # @raise [CoercionError] when value cannot be coerced to expected type
    #
    # @example Coerce parameter value
    #   evaluator.send(:coerce!) #=> 42
    def coerce!
      types = Array(type)
      tsize = types.size - 1

      types.each_with_index do |key, i|
        break CMDx.configuration.coercions.call(task, key, value, options)
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
    #
    # @example Check if validations should be skipped
    #   evaluator.send(:skip_validations_due_to_optional_missing_argument?) #=> false
    def skip_validations_due_to_optional_missing_argument?
      optional? && value.nil? && !source.nil? && !source.cmdx_respond_to?(name, true)
    end

    # Checks if validator should be skipped due to conditional options.
    #
    # @param opts [Hash] the validator options
    #
    # @return [Boolean] true if validator should be skipped, false otherwise
    #
    # @example Check if validator should be skipped
    #   evaluator.send(:skip_validator_due_to_conditional?, :presence) #=> false
    def skip_validator_due_to_conditional?(opts)
      opts.is_a?(Hash) && !task.cmdx_eval(opts)
    end

    # Checks if validator should be skipped due to allow_nil option.
    #
    # @param opts [Symbol] the validator options
    #
    # @return [Boolean] true if validator should be skipped, false otherwise
    #
    # @example Check if validator should be skipped for nil
    #   evaluator.send(:skip_validator_due_to_allow_nil?, :presence) #=> true
    def skip_validator_due_to_allow_nil?(opts)
      opts.is_a?(Hash) && opts[:allow_nil] && value.nil?
    end

    # Applies all configured validations to the parameter value.
    #
    # @return [void]
    #
    # @raise [ValidationError] when parameter value fails validation
    #
    # @example Validate parameter value
    #   evaluator.send(:validate!)
    def validate!
      return if skip_validations_due_to_optional_missing_argument?

      types = CMDx.configuration.validators.registry.keys

      options.slice(*types).each_key do |key|
        opts = options[key]
        next if skip_validator_due_to_allow_nil?(opts)
        next if skip_validator_due_to_conditional?(opts)

        CMDx.configuration.validators.call(task, key, value, opts)
      end
    end

  end
end
