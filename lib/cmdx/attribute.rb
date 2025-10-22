# frozen_string_literal: true

module CMDx
  # Represents a configurable attribute within a CMDx task.
  # Attributes define the data structure and validation rules for task parameters.
  # They can be nested to create complex hierarchical data structures.
  class Attribute

    # @rbs AFFIX: Proc
    AFFIX = proc do |value, &block|
      value == true ? block.call : value
    end.freeze
    private_constant :AFFIX

    # Returns the task instance associated with this attribute.
    #
    # @return [CMDx::Task] The task instance
    #
    # @example
    #   attribute.task.context[:user_id] # => 42
    #
    # @rbs @task: Task
    attr_accessor :task

    # Returns the name of this attribute.
    #
    # @return [Symbol] The attribute name
    #
    # @example
    #   attribute.name # => :user_id
    #
    # @rbs @name: Symbol
    attr_reader :name

    # Returns the configuration options for this attribute.
    #
    # @return [Hash{Symbol => Object}] Configuration options hash
    #
    # @example
    #   attribute.options # => { required: true, default: 0 }
    #
    # @rbs @options: Hash[Symbol, untyped]
    attr_reader :options

    # Returns the child attributes for nested structures.
    #
    # @return [Array<Attribute>] Array of child attributes
    #
    # @example
    #   attribute.children # => [#<Attribute @name=:street>, #<Attribute @name=:city>]
    #
    # @rbs @children: Array[Attribute]
    attr_reader :children

    # Returns the parent attribute if this is a nested attribute.
    #
    # @return [Attribute, nil] The parent attribute, or nil if root-level
    #
    # @example
    #   attribute.parent # => #<Attribute @name=:address>
    #
    # @rbs @parent: (Attribute | nil)
    attr_reader :parent

    # Returns the expected type(s) for this attribute's value.
    #
    # @return [Array<Class>] Array of expected type classes
    #
    # @example
    #   attribute.types # => [Integer, String]
    #
    # @rbs @types: Array[Class]
    attr_reader :types

    # Creates a new attribute with the specified name and configuration.
    #
    # @param name [Symbol, String] The name of the attribute
    # @param options [Hash] Configuration options for the attribute
    # @option options [Attribute] :parent The parent attribute for nested structures
    # @option options [Boolean] :required Whether the attribute is required (default: false)
    # @option options [Array<Class>, Class] :types The expected type(s) for the attribute value
    # @option options [Symbol, String, Proc] :source The source of the attribute value
    # @option options [Symbol, String] :as The method name to use for this attribute
    # @option options [Symbol, String, Boolean] :prefix The prefix to add to the method name
    # @option options [Symbol, String, Boolean] :suffix The suffix to add to the method name
    # @option options [Object] :default The default value for the attribute
    #
    # @yield [self] Block to configure nested attributes
    #
    # @example
    #   Attribute.new(:user_id, required: true, types: [Integer, String]) do
    #     required :name, types: String
    #     optional :email, types: String
    #   end
    #
    # @rbs ((Symbol | String) name, ?Hash[Symbol, untyped] options) ?{ () -> void } -> void
    def initialize(name, options = {}, &)
      @parent = options.delete(:parent)
      @required = options.delete(:required) || false
      @types = Array(options.delete(:types) || options.delete(:type))

      @name = name.to_sym
      @options = options
      @children = []

      instance_eval(&) if block_given?
    end

    class << self

      # Builds multiple attributes with the same configuration.
      #
      # @param names [Array<Symbol, String>] The names of the attributes to create
      # @param options [Hash] Configuration options for the attributes
      #
      # @yield [self] Block to configure nested attributes
      #
      # @return [Array<Attribute>] Array of created attributes
      #
      # @raise [ArgumentError] When no names are provided or :as is used with multiple attributes
      #
      # @example
      #   Attribute.build(:first_name, :last_name, required: true, types: String)
      #
      # @rbs (*untyped names, **untyped options) ?{ () -> void } -> Array[Attribute]
      def build(*names, **options, &)
        if names.none?
          raise ArgumentError, "no attributes given"
        elsif (names.size > 1) && options.key?(:as)
          raise ArgumentError, "the :as option only supports one attribute per definition"
        end

        names.filter_map { |name| new(name, **options, &) }
      end

      # Creates optional attributes (not required).
      #
      # @param names [Array<Symbol, String>] The names of the attributes to create
      # @param options [Hash] Configuration options for the attributes
      #
      # @yield [self] Block to configure nested attributes
      #
      # @return [Array<Attribute>] Array of created optional attributes
      #
      # @example
      #   Attribute.optional(:description, :tags, types: String)
      #
      # @rbs (*untyped names, **untyped options) ?{ () -> void } -> Array[Attribute]
      def optional(*names, **options, &)
        build(*names, **options.merge(required: false), &)
      end

      # Creates required attributes.
      #
      # @param names [Array<Symbol, String>] The names of the attributes to create
      # @param options [Hash] Configuration options for the attributes
      #
      # @yield [self] Block to configure nested attributes
      #
      # @return [Array<Attribute>] Array of created required attributes
      #
      # @example
      #   Attribute.required(:id, :name, types: [Integer, String])
      #
      # @rbs (*untyped names, **untyped options) ?{ () -> void } -> Array[Attribute]
      def required(*names, **options, &)
        build(*names, **options.merge(required: true), &)
      end

    end

    # Checks if the attribute is required.
    #
    # @return [Boolean] true if the attribute is required, false otherwise
    #
    # @example
    #   attribute.required? # => true
    #
    # @rbs () -> bool
    def required?
      !!@required
    end

    # Determines the source of the attribute value.
    #
    # @return [Symbol] The source identifier for the attribute value
    #
    # @example
    #   attribute.source # => :context
    #
    # @rbs () -> untyped
    def source
      @source ||= parent&.method_name || begin
        value = options[:source]

        if value.is_a?(Proc)
          task.instance_eval(&value)
        elsif value.respond_to?(:call)
          value.call(task)
        else
          value || :context
        end
      end
    end

    # Generates the method name for accessing this attribute.
    #
    # @return [Symbol] The method name for the attribute
    #
    # @example
    #   attribute.method_name # => :user_name
    #
    # @rbs () -> Symbol
    def method_name
      @method_name ||= options[:as] || begin
        prefix = AFFIX.call(options[:prefix]) { "#{source}_" }
        suffix = AFFIX.call(options[:suffix]) { "_#{source}" }

        :"#{prefix}#{name}#{suffix}"
      end
    end

    # Defines and verifies the entire attribute tree including nested children.
    #
    # @rbs () -> void
    def define_and_verify_tree
      define_and_verify

      children.each do |child|
        child.task = task
        child.define_and_verify_tree
      end
    end

    private

    # Creates nested attributes as children of this attribute.
    #
    # @param names [Array<Symbol, String>] The names of the child attributes
    # @param options [Hash] Configuration options for the child attributes
    #
    # @yield [self] Block to configure the child attributes
    #
    # @return [Array<Attribute>] Array of created child attributes
    #
    # @example
    #   attributes :street, :city, :zip, types: String
    #
    # @rbs (*untyped names, **untyped options) ?{ () -> void } -> Array[Attribute]
    def attributes(*names, **options, &)
      attrs = self.class.build(*names, **options.merge(parent: self), &)
      children.concat(attrs)
    end
    alias attribute attributes

    # Creates optional nested attributes.
    #
    # @param names [Array<Symbol, String>] The names of the optional child attributes
    # @param options [Hash] Configuration options for the child attributes
    #
    # @yield [self] Block to configure the child attributes
    #
    # @return [Array<Attribute>] Array of created optional child attributes
    #
    # @example
    #   optional :middle_name, :nickname, types: String
    #
    # @rbs (*untyped names, **untyped options) ?{ () -> void } -> Array[Attribute]
    def optional(*names, **options, &)
      attributes(*names, **options.merge(required: false), &)
    end

    # Creates required nested attributes.
    #
    # @param names [Array<Symbol, String>] The names of the required child attributes
    # @param options [Hash] Configuration options for the child attributes
    #
    # @yield [self] Block to configure the child attributes
    #
    # @return [Array<Attribute>] Array of created required child attributes
    #
    # @example
    #   required :first_name, :last_name, types: String
    #
    # @rbs (*untyped names, **untyped options) ?{ () -> void } -> Array[Attribute]
    def required(*names, **options, &)
      attributes(*names, **options.merge(required: true), &)
    end

    # Defines the attribute method on the task and validates the configuration.
    #
    # @raise [RuntimeError] When the method name is already defined on the task
    #
    # @rbs () -> void
    def define_and_verify
      if task.respond_to?(method_name, true)
        raise <<~MESSAGE
          The method #{method_name.inspect} is already defined on the #{task.class.name} task.
          This may be due conflicts with one of the task's user defined or internal methods/attributes.

          Use :as, :prefix, and/or :suffix attribute options to avoid conflicts with existing methods.
        MESSAGE
      end

      attribute_value = AttributeValue.new(self)
      attribute_value.generate
      attribute_value.validate

      task.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        def #{method_name}
          attributes[:#{method_name}]
        end
      RUBY
    end

  end
end
