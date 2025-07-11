# frozen_string_literal: true

module CMDx
  # Parameter definition system for CMDx tasks.
  #
  # This class manages parameter definitions including type coercion, validation,
  # and nested parameter structures. It handles the creation of accessor methods
  # on task classes and provides a flexible system for defining required and
  # optional parameters with various data types and validation rules.
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

    # Creates a new parameter definition with the given name and options.
    #
    # @param name [Symbol] The parameter name
    # @param options [Hash] Configuration options for the parameter
    # @option options [Class] :klass The task class this parameter belongs to (required)
    # @option options [Parameter] :parent The parent parameter for nested parameters
    # @option options [Symbol, Array<Symbol>] :type (:virtual) The parameter type(s) for coercion
    # @option options [Boolean] :required (false) Whether the parameter is required
    # @param block [Proc] Optional block for defining nested parameters
    # @return [Parameter] The newly created parameter
    # @raise [KeyError] If the :klass option is not provided
    #
    # @example Create a simple parameter
    #   Parameter.new(:name, klass: MyTask, type: :string, required: true)
    #
    # @example Create a parameter with nested children
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

      # Creates one or more optional parameters with the given names and options.
      #
      # @param names [Array<Symbol>] Parameter names to create
      # @param options [Hash] Configuration options for all parameters
      # @param block [Proc] Optional block for defining nested parameters
      # @return [Array<Parameter>] The created optional parameters
      # @raise [ArgumentError] If no parameters are given or :as option is used with multiple names
      #
      # @example Create multiple optional parameters
      #   Parameter.optional(:name, :email, type: :string, klass: MyTask)
      #
      # @example Create optional parameter with nested structure
      #   Parameter.optional(:user, klass: MyTask, type: :hash) do
      #     required :name, type: :string
      #   end
      def optional(*names, **options, &)
        if names.none?
          raise ArgumentError, "no parameters given"
        elsif !names.one? && options.key?(:as)
          raise ArgumentError, ":as option only supports one parameter per definition"
        end

        names.filter_map { |n| new(n, **options, &) }
      end

      # Creates one or more required parameters with the given names and options.
      #
      # @param names [Array<Symbol>] Parameter names to create
      # @param options [Hash] Configuration options for all parameters
      # @param block [Proc] Optional block for defining nested parameters
      # @return [Array<Parameter>] The created required parameters
      # @raise [ArgumentError] If no parameters are given or :as option is used with multiple names
      #
      # @example Create multiple required parameters
      #   Parameter.required(:name, :email, type: :string, klass: MyTask)
      #
      # @example Create required parameter with validation
      #   Parameter.required(:age, type: :integer, validate: { numeric: { greater_than: 0 } }, klass: MyTask)
      def required(*names, **options, &)
        optional(*names, **options.merge(required: true), &)
      end

    end

    # Creates one or more optional child parameters under this parameter.
    #
    # @param names [Array<Symbol>] Parameter names to create
    # @param options [Hash] Configuration options for all parameters
    # @param block [Proc] Optional block for defining nested parameters
    # @return [Array<Parameter>] The created optional child parameters
    #
    # @example Add optional child parameters
    #   user_param.optional(:nickname, :bio, type: :string)
    #
    # @example Add optional child with further nesting
    #   user_param.optional(:preferences, type: :hash) do
    #     required :theme, type: :string
    #   end
    def optional(*names, **options, &)
      parameters = Parameter.optional(*names, **options.merge(klass: @klass, parent: self), &)
      children.concat(parameters)
    end

    # Creates one or more required child parameters under this parameter.
    #
    # @param names [Array<Symbol>] Parameter names to create
    # @param options [Hash] Configuration options for all parameters
    # @param block [Proc] Optional block for defining nested parameters
    # @return [Array<Parameter>] The created required child parameters
    #
    # @example Add required child parameters
    #   user_param.required(:first_name, :last_name, type: :string)
    #
    # @example Add required child with validation
    #   user_param.required(:email, type: :string, validate: { format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i } })
    def required(*names, **options, &)
      parameters = Parameter.required(*names, **options.merge(klass: @klass, parent: self), &)
      children.concat(parameters)
    end

    # Checks if this parameter is required.
    #
    # @return [Boolean] True if the parameter is required, false otherwise
    #
    # @example Check if parameter is required
    #   param.required? # => true
    def required?
      !!@required
    end

    # Checks if this parameter is optional.
    #
    # @return [Boolean] True if the parameter is optional, false otherwise
    #
    # @example Check if parameter is optional
    #   param.optional? # => false
    def optional?
      !required?
    end

    # Gets the method name that will be used to access this parameter's value.
    #
    # @return [Symbol] The method name for accessing this parameter
    #
    # @example Get method name
    #   param.method_name # => :user_name
    def method_name
      @method_name ||= Utils::NameAffix.call(name, method_source, options)
    end

    # Gets the source object from which this parameter's value will be retrieved.
    #
    # @return [Symbol] The method source (:context by default, or parent's method_name)
    #
    # @example Get method source
    #   param.method_source # => :context
    def method_source
      @method_source ||= options[:source] || parent&.method_name || :context
    end

    # Converts the parameter to a hash representation.
    #
    # @return [Hash] A hash representation of the parameter
    #
    # @example Convert to hash
    #   param.to_h # => { name: :user_name, type: :string, required: true, ... }
    def to_h
      ParameterSerializer.call(self)
    end

    # Converts the parameter to a string representation.
    #
    # @return [String] A string representation of the parameter
    #
    # @example Convert to string
    #   param.to_s # => "Parameter(name: user_name, type: string, required: true)"
    def to_s
      ParameterInspector.call(to_h)
    end

    private

    # Defines the attribute accessor method for this parameter on the task class.
    # The method handles parameter value retrieval, coercion, and validation.
    #
    # @param parameter [Parameter] The parameter to define the method for
    # @return [void]
    # @raise [CoercionError] If parameter value cannot be coerced to the expected type
    # @raise [ValidationError] If parameter value fails validation
    #
    # @example Define parameter method (internal use)
    #   define_attribute(param) # Defines a private method on the task class
    def define_attribute(parameter)
      klass.send(:define_method, parameter.method_name) do
        @parameters_cache ||= {}
        return @parameters_cache[parameter.method_name] if @parameters_cache.key?(parameter.method_name)

        begin
          parameter_value = ParameterValue.new(self, parameter).call
        rescue CoercionError, ValidationError => e
          parameter.errors.add(parameter.method_name, e.message)
          errors.merge!(parameter.errors.to_hash)
        ensure
          @parameters_cache[parameter.method_name] = parameter_value
        end

        @parameters_cache[parameter.method_name]
      end

      klass.send(:private, parameter.method_name)
    end

  end
end
