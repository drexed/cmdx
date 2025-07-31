# frozen_string_literal: true

module CMDx
  # Parameter definition and management for task attribute configuration.
  #
  # Parameter provides a flexible system for defining, validating, and managing
  # task parameters with support for type coercion, nested parameter structures,
  # validation rules, and dynamic attribute generation. Parameters can be defined
  # as required or optional with various configuration options including custom
  # naming, source specification, and child parameter definitions.
  class Parameter

    cmdx_attr_delegator :invalid?, :valid?,
                        to: :errors

    # @return [CMDx::Task] The task class this parameter belongs to
    attr_accessor :task

    # @return [Class] The task class this parameter is defined in
    attr_reader :klass

    # @return [Parameter, nil] The parent parameter for nested parameters
    attr_reader :parent

    # @return [Symbol] The parameter name
    attr_reader :name

    # @return [Symbol, Array<Symbol>] The parameter type(s) for coercion
    attr_reader :type

    # @return [Hash] The parameter configuration options
    attr_reader :options

    # @return [Array<Parameter>] Child parameters for nested parameter definitions
    attr_reader :children

    # @return [CMDx::Errors] Validation errors for this parameter
    attr_reader :errors

    # Creates a new parameter definition with the specified configuration.
    #
    # @param name [Symbol, String] the parameter name
    # @param options [Hash] parameter configuration options
    # @option options [Class] :klass the task class this parameter belongs to (required)
    # @option options [Parameter] :parent the parent parameter for nested definitions
    # @option options [Symbol, Array<Symbol>] :type the parameter type(s) for coercion
    # @option options [Boolean] :required whether the parameter is required for task execution
    # @option options [Symbol] :source the source context for parameter resolution
    # @option options [Symbol, String] :as custom method name for the parameter
    # @option options [Hash] :validates validation rules to apply to the parameter
    # @option options [Object] :default default value when parameter is not provided
    # @param block [Proc] optional block for defining nested parameters
    #
    # @return [Parameter] a new parameter instance
    #
    # @raise [KeyError] if the :klass option is not provided
    #
    # @example Create a simple required parameter
    #   Parameter.new(:user_id, klass: MyTask, type: :integer, required: true)
    #
    # @example Create parameter with validation
    #   Parameter.new(:email, klass: MyTask, type: :string, validates: { format: /@/ })
    #
    # @example Create nested parameter with children
    #   Parameter.new(:user, klass: MyTask, type: :hash) do
    #     required :name, type: :string
    #     optional :age, type: :integer
    #   end
    def initialize(name, **options, &)
      @klass    = options.delete(:klass) || raise(KeyError, "klass option required")
      @parent   = options.delete(:parent)
      @type     = options.delete(:type) || :virtual
      @required = options.delete(:required) || false

      @name     = name
      @options  = options
      @children = []
      @errors   = Errors.new

      define_attribute(self)
      instance_eval(&) if block_given?
    end

    class << self

      # Creates one or more optional parameter definitions.
      #
      # @param names [Array<Symbol>] parameter names to define as optional
      # @param options [Hash] parameter configuration options
      # @option options [Class] :klass the task class this parameter belongs to
      # @option options [Parameter] :parent the parent parameter for nested definitions
      # @option options [Symbol, Array<Symbol>] :type the parameter type(s) for coercion
      # @option options [Symbol] :source the source context for parameter resolution
      # @option options [Symbol, String] :as custom method name (only allowed for single parameter)
      # @option options [Hash] :validates validation rules to apply to the parameter
      # @option options [Object] :default default value when parameter is not provided
      # @param block [Proc] optional block for defining nested parameters
      #
      # @return [Array<Parameter>] array of created optional parameter instances
      #
      # @raise [ArgumentError] if no parameter names are provided
      # @raise [ArgumentError] if :as option is used with multiple parameter names
      #
      # @example Define single optional parameter
      #   Parameter.optional(:description, klass: MyTask, type: :string)
      #
      # @example Define multiple optional parameters
      #   Parameter.optional(:name, :email, klass: MyTask, type: :string)
      #
      # @example Define optional parameter with custom name
      #   Parameter.optional(:user_id, klass: MyTask, type: :integer, as: :current_user_id)
      def optional(*names, **options, &)
        if names.none?
          raise ArgumentError, "no parameters given"
        elsif !names.one? && options.key?(:as)
          raise ArgumentError, ":as option only supports one parameter per definition"
        end

        names.filter_map { |n| new(n, **options, &) }
      end

      # Creates one or more required parameter definitions.
      #
      # @param names [Array<Symbol>] parameter names to define as required
      # @param options [Hash] parameter configuration options
      # @option options [Class] :klass the task class this parameter belongs to
      # @option options [Parameter] :parent the parent parameter for nested definitions
      # @option options [Symbol, Array<Symbol>] :type the parameter type(s) for coercion
      # @option options [Symbol] :source the source context for parameter resolution
      # @option options [Symbol, String] :as custom method name (only allowed for single parameter)
      # @option options [Hash] :validates validation rules to apply to the parameter
      # @option options [Object] :default default value when parameter is not provided
      # @param block [Proc] optional block for defining nested parameters
      #
      # @return [Array<Parameter>] array of created required parameter instances
      #
      # @raise [ArgumentError] if no parameter names are provided
      # @raise [ArgumentError] if :as option is used with multiple parameter names
      #
      # @example Define single required parameter
      #   Parameter.required(:user_id, klass: MyTask, type: :integer)
      #
      # @example Define multiple required parameters
      #   Parameter.required(:name, :email, klass: MyTask, type: :string)
      #
      # @example Define required parameter with validation
      #   Parameter.required(:email, klass: MyTask, type: :string, validates: { format: /@/ })
      def required(*names, **options, &)
        optional(*names, **options.merge(required: true), &)
      end

    end

    # Defines optional child parameters for nested parameter structures.
    #
    # @param names [Array<Symbol>] parameter names to define as optional children
    # @param options [Hash] parameter configuration options
    # @option options [Symbol, Array<Symbol>] :type the parameter type(s) for coercion
    # @option options [Symbol] :source the source context for parameter resolution
    # @option options [Symbol, String] :as custom method name (only allowed for single parameter)
    # @option options [Hash] :validates validation rules to apply to the parameter
    # @option options [Object] :default default value when parameter is not provided
    # @param block [Proc] optional block for defining nested parameters
    #
    # @return [Array<Parameter>] array of created optional child parameter instances
    #
    # @raise [ArgumentError] if no parameter names are provided
    # @raise [ArgumentError] if :as option is used with multiple parameter names
    #
    # @example Define optional child parameters
    #   user_param = Parameter.new(:user, klass: MyTask, type: :hash)
    #   user_param.optional(:description, :bio, type: :string)
    def optional(*names, **options, &)
      parameters = Parameter.optional(*names, **options.merge(klass: @klass, parent: self), &)
      children.concat(parameters)
    end

    # Defines required child parameters for nested parameter structures.
    #
    # @param names [Array<Symbol>] parameter names to define as required children
    # @param options [Hash] parameter configuration options
    # @option options [Symbol, Array<Symbol>] :type the parameter type(s) for coercion
    # @option options [Symbol] :source the source context for parameter resolution
    # @option options [Symbol, String] :as custom method name (only allowed for single parameter)
    # @option options [Hash] :validates validation rules to apply to the parameter
    # @option options [Object] :default default value when parameter is not provided
    # @param block [Proc] optional block for defining nested parameters
    #
    # @return [Array<Parameter>] array of created required child parameter instances
    #
    # @raise [ArgumentError] if no parameter names are provided
    # @raise [ArgumentError] if :as option is used with multiple parameter names
    #
    # @example Define required child parameters
    #   user_param = Parameter.new(:user, klass: MyTask, type: :hash)
    #   user_param.required(:name, :email, type: :string)
    def required(*names, **options, &)
      parameters = Parameter.required(*names, **options.merge(klass: @klass, parent: self), &)
      children.concat(parameters)
    end

    # Checks if the parameter is marked as required for task execution.
    #
    # @return [Boolean] true if the parameter is required, false otherwise
    #
    # @example Check if parameter is required
    #   param = Parameter.new(:name, klass: MyTask, required: true)
    #   param.required? #=> true
    def required?
      !!@required
    end

    # Checks if the parameter is marked as optional for task execution.
    #
    # @return [Boolean] true if the parameter is optional, false otherwise
    #
    # @example Check if parameter is optional
    #   param = Parameter.new(:description, klass: MyTask, required: false)
    #   param.optional? #=> true
    def optional?
      !required?
    end

    # Generates the method name that will be created on the task class for this parameter.
    #
    # @return [Symbol] the method name with any configured prefix, suffix, or custom naming
    #
    # @example Get method name for simple parameter
    #   param = Parameter.new(:user_id, klass: MyTask)
    #   param.method_name #=> :user_id
    #
    # @example Get method name with custom naming
    #   param = Parameter.new(:user_id, klass: MyTask, as: :current_user_id)
    #   param.method_name #=> :current_user_id
    def method_name
      @method_name ||= Utils::NameAffix.call(name, method_source, options)
    end

    # Determines the source context for parameter resolution and method name generation.
    #
    # @return [Symbol] the source identifier used for parameter resolution
    #
    # @example Get method source for simple parameter
    #   param = Parameter.new(:user_id, klass: MyTask)
    #   param.method_source #=> :context
    #
    # @example Get method source for nested parameter
    #   parent = Parameter.new(:user, klass: MyTask)
    #   child = Parameter.new(:name, klass: MyTask, parent: parent)
    #   child.method_source #=> :user
    def method_source
      @method_source ||= options[:source] || parent&.method_name || :context
    end

    # Converts the parameter to a hash representation for serialization.
    #
    # @return [Hash] hash containing all parameter metadata and configuration
    #
    # @example Convert parameter to hash
    #   param = Parameter.new(:user_id, klass: MyTask, type: :integer, required: true)
    #   param.to_h
    #   #=> { name: :user_id, type: :integer, required: true, ... }
    def to_h
      ParameterSerializer.call(self)
    end

    # Converts the parameter to a formatted string representation for inspection.
    #
    # @return [String] human-readable string representation of the parameter
    #
    # @example Convert parameter to string
    #   param = Parameter.new(:user_id, klass: MyTask, type: :integer, required: true)
    #   param.to_s
    #   #=> "Parameter: name=user_id type=integer required=true ..."
    def to_s
      ParameterInspector.call(to_h)
    end

    private

    # Dynamically defines a method on the task class for parameter value access.
    #
    # @param parameter [Parameter] the parameter to create a method for
    #
    # @return [void]
    #
    # @example Define parameter method on task class
    #   # Creates a private method that evaluates and caches parameter values
    #   # with automatic error handling for coercion and validation failures
    def define_attribute(parameter)
      klass.send(:define_method, parameter.method_name) do
        @cmd_parameter_value_cache ||= {}

        unless @cmd_parameter_value_cache.key?(parameter.method_name)
          begin
            parameter_value = ParameterEvaluator.call(self, parameter)
          rescue CoercionError, ValidationError => e
            parameter.errors.add(parameter.method_name, e.message)
            errors.merge!(parameter.errors.to_hash)
          ensure
            @cmd_parameter_value_cache[parameter.method_name] = parameter_value
          end
        end

        @cmd_parameter_value_cache[parameter.method_name]
      end

      klass.send(:private, parameter.method_name)
    end

  end
end
