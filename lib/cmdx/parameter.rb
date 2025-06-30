# frozen_string_literal: true

module CMDx
  # Parameter definition class for CMDx task parameter management.
  #
  # The Parameter class represents individual parameter definitions within CMDx tasks.
  # It handles parameter configuration, validation rules, type coercion, nested parameters,
  # and method generation for accessing parameter values within task instances.
  #
  # @example Basic parameter definition
  #   class ProcessOrderTask < CMDx::Task
  #     required :order_id
  #     optional :priority
  #   end
  #
  # @example Parameter with type coercion and validation
  #   class ProcessUserTask < CMDx::Task
  #     required :age, type: :integer, numeric: { min: 18, max: 120 }
  #     required :email, type: :string, format: { with: /@/ }
  #   end
  #
  # @example Nested parameters
  #   class ProcessOrderTask < CMDx::Task
  #     required :shipping_address do
  #       required :street, :city, :state
  #       optional :apartment
  #     end
  #   end
  #
  # @example Parameter with custom source
  #   class ProcessUserTask < CMDx::Task
  #     required :name, source: :user
  #     required :company_name, source: -> { user.company }
  #   end
  #
  # @example Parameter with default values
  #   class ProcessOrderTask < CMDx::Task
  #     optional :priority, default: "normal"
  #     optional :notification, default: -> { user.preferences.notify? }
  #   end
  #
  # @see CMDx::Task Task parameter integration
  # @see CMDx::ParameterValue Parameter value resolution and validation
  # @see CMDx::Parameters Parameter collection management
  class Parameter

    __cmdx_attr_delegator :invalid?, :valid?,
                          to: :errors

    # @return [CMDx::Task] The task class this parameter belongs to
    attr_accessor :task

    # @return [Class] The task class this parameter is defined in
    # @return [Parameter, nil] The parent parameter for nested parameters
    # @return [Symbol] The parameter name
    # @return [Symbol, Array<Symbol>] The parameter type(s) for coercion
    # @return [Hash] The parameter configuration options
    # @return [Array<Parameter>] Child parameters for nested parameter definitions
    # @return [CMDx::Errors] Validation errors for this parameter
    attr_reader :klass, :parent, :name, :type, :options, :children, :errors

    # Initializes a new Parameter instance.
    #
    # Creates a parameter definition with the specified configuration options.
    # Automatically defines accessor methods on the task class and processes
    # any nested parameter definitions provided via block.
    #
    # @param name [Symbol] The parameter name
    # @param options [Hash] Parameter configuration options
    # @option options [Class] :klass The task class (required)
    # @option options [Parameter] :parent Parent parameter for nesting
    # @option options [Symbol, Array<Symbol>] :type (:virtual) Type(s) for coercion
    # @option options [Boolean] :required (false) Whether parameter is required
    # @option options [Object, Proc] :default Default value or callable
    # @option options [Symbol, Proc] :source (:context) Parameter value source
    # @option options [Hash] :* Validation options (presence, format, etc.)
    #
    # @yield Optional block for defining nested parameters
    #
    # @raise [KeyError] If :klass option is not provided
    #
    # @example Basic parameter creation
    #   Parameter.new(:user_id, klass: MyTask, type: :integer, required: true)
    #
    # @example Parameter with validation
    #   Parameter.new(:email, klass: MyTask, type: :string,
    #                 format: { with: /@/ }, presence: true)
    #
    # @example Nested parameter with block
    #   Parameter.new(:address, klass: MyTask) do
    #     required :street, :city
    #     optional :apartment
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

      # Defines one or more optional parameters.
      #
      # Creates parameter definitions that are not required for task execution.
      # Optional parameters return nil if not provided in the call arguments.
      #
      # @param names [Array<Symbol>] Parameter names to define
      # @param options [Hash] Parameter configuration options
      # @yield Optional block for nested parameter definitions
      #
      # @return [Array<Parameter>] Created parameter instances
      # @raise [ArgumentError] If no parameter names provided or :as option used with multiple names
      #
      # @example Single optional parameter
      #   Parameter.optional(:priority, type: :string, default: "normal")
      #
      # @example Multiple optional parameters
      #   Parameter.optional(:width, :height, type: :integer, numeric: { min: 0 })
      #
      # @example Optional parameter with validation
      #   Parameter.optional(:email, type: :string, format: { with: /@/ })
      def optional(*names, **options, &)
        if names.none?
          raise ArgumentError, "no parameters given"
        elsif !names.one? && options.key?(:as)
          raise ArgumentError, ":as option only supports one parameter per definition"
        end

        names.filter_map { |n| new(n, **options, &) }
      end

      # Defines one or more required parameters.
      #
      # Creates parameter definitions that must be provided for task execution.
      # Missing required parameters will cause task validation to fail.
      #
      # @param names [Array<Symbol>] Parameter names to define
      # @param options [Hash] Parameter configuration options
      # @yield Optional block for nested parameter definitions
      #
      # @return [Array<Parameter>] Created parameter instances
      # @raise [ArgumentError] If no parameter names provided or :as option used with multiple names
      #
      # @example Single required parameter
      #   Parameter.required(:user_id, type: :integer)
      #
      # @example Multiple required parameters
      #   Parameter.required(:first_name, :last_name, type: :string, presence: true)
      #
      # @example Required parameter with complex validation
      #   Parameter.required(:age, type: :integer, numeric: { within: 18..120 })
      def required(*names, **options, &)
        optional(*names, **options.merge(required: true), &)
      end

    end

    # Defines nested optional parameters within this parameter.
    #
    # Creates child parameter definitions that inherit this parameter as their source.
    # Child parameters are only validated if the parent parameter is provided.
    #
    # @param names [Array<Symbol>] Child parameter names to define
    # @param options [Hash] Parameter configuration options
    # @yield Optional block for further nested parameter definitions
    #
    # @return [Array<Parameter>] Created child parameter instances
    #
    # @example Nested optional parameters
    #   address_param.optional(:apartment, :unit, type: :string)
    #
    # @example Nested parameter with validation
    #   user_param.optional(:age, type: :integer, numeric: { min: 0 })
    def optional(*names, **options, &)
      parameters = Parameter.optional(*names, **options.merge(klass: @klass, parent: self), &)
      children.concat(parameters)
    end

    # Defines nested required parameters within this parameter.
    #
    # Creates child parameter definitions that are required if the parent parameter
    # is provided. Child parameters inherit this parameter as their source.
    #
    # @param names [Array<Symbol>] Child parameter names to define
    # @param options [Hash] Parameter configuration options
    # @yield Optional block for further nested parameter definitions
    #
    # @return [Array<Parameter>] Created child parameter instances
    #
    # @example Nested required parameters
    #   address_param.required(:street, :city, :state, type: :string)
    #
    # @example Nested parameter with validation
    #   payment_param.required(:amount, type: :float, numeric: { min: 0.01 })
    def required(*names, **options, &)
      parameters = Parameter.required(*names, **options.merge(klass: @klass, parent: self), &)
      children.concat(parameters)
    end

    # Checks if this parameter is required.
    #
    # @return [Boolean] true if parameter is required, false otherwise
    #
    # @example
    #   required_param.required?  # => true
    #   optional_param.required?  # => false
    def required?
      !!@required
    end

    # Checks if this parameter is optional.
    #
    # @return [Boolean] true if parameter is optional, false otherwise
    #
    # @example
    #   required_param.optional?  # => false
    #   optional_param.optional?  # => true
    def optional?
      !required?
    end

    # Gets the method name that will be defined on the task class.
    #
    # The method name is generated using NameAffix utility and can be customized
    # with :as, :prefix, and :suffix options.
    #
    # @return [Symbol] The generated method name
    #
    # @example Default method name
    #   Parameter.new(:user_id, klass: Task).method_name  # => :user_id
    #
    # @example Custom method name
    #   Parameter.new(:id, klass: Task, as: :user_id).method_name  # => :user_id
    #
    # @example Method name with prefix
    #   Parameter.new(:name, klass: Task, prefix: "get_").method_name  # => :get_name
    def method_name
      @method_name ||= Utils::NameAffix.call(name, method_source, options)
    end

    # Gets the source object/method that provides the parameter value.
    #
    # Determines where the parameter value should be retrieved from, defaulting
    # to :context or inheriting from parent parameter.
    #
    # @return [Symbol] The source method name
    #
    # @example Default source
    #   Parameter.new(:user_id, klass: Task).method_source  # => :context
    #
    # @example Custom source
    #   Parameter.new(:name, klass: Task, source: :user).method_source  # => :user
    #
    # @example Inherited source from parent
    #   child_param.method_source  # => parent parameter's method_name
    def method_source
      @method_source ||= options[:source] || parent&.method_name || :context
    end

    # Converts the parameter to a hash representation.
    #
    # @return [Hash] Serialized parameter data including configuration and children
    #
    # @example
    #   param.to_h
    #   # => {
    #   #   source: :context,
    #   #   name: :user_id,
    #   #   type: :integer,
    #   #   required: true,
    #   #   options: { numeric: { min: 1 } },
    #   #   children: []
    #   # }
    def to_h
      ParameterSerializer.call(self)
    end

    # Converts the parameter to a string representation for inspection.
    #
    # @return [String] Human-readable parameter description
    #
    # @example
    #   param.to_s
    #   # => "Parameter: name=user_id type=integer source=context required=true options={numeric: {min: 1}}"
    def to_s
      ParameterInspector.call(to_h)
    end

    private

    # Defines the accessor method on the task class for this parameter.
    #
    # Creates a private method that handles parameter value resolution,
    # type coercion, validation, and error handling with caching.
    #
    # @param parameter [Parameter] The parameter to define method for
    # @return [void]
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
