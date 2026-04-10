# frozen_string_literal: true

module CMDx
  # Base class for all tasks. Composed from focused modules for each concern.
  #
  # Developers subclass Task and implement `#work`. Optionally override `#rollback`.
  #
  # @example
  #   class CreateUser < CMDx::Task
  #     required :email, :string
  #
  #     def work
  #       ctx[:user] = User.create!(email:)
  #     end
  #   end
  class Task

    include Signals

    # @return [Context] the shared execution context
    attr_reader :context
    alias ctx context

    # The main entry point — subclasses MUST override this.
    #
    # @raise [UndefinedMethodError] when not overridden
    #
    # @rbs () -> void
    def work
      raise UndefinedMethodError, "undefined method #{self.class.name}#work"
    end

    # Optional rollback — called when execution fails.
    #
    # @rbs () -> void
    def rollback; end

    # @return [Logger] memoized logger with task-level overrides
    #
    # @rbs () -> Logger
    def logger
      @logger ||= resolve_logger
    end

    class << self

      # Executes the task and returns a frozen Result.
      #
      # @param args [Hash] input arguments
      #
      # @return [Result]
      #
      # @rbs (**untyped args) ?{ (Result) -> void } -> Result
      def execute(**args, &)
        Runtime.call(self, args, raise_on_fault: false, &)
      end

      # Executes the task; raises FailFault or SkipFault on non-success.
      #
      # @param args [Hash] input arguments
      #
      # @return [Result]
      # @raise [FailFault] on failure
      # @raise [SkipFault] on skip
      #
      # @rbs (**untyped args) ?{ (Result) -> void } -> Result
      def execute!(**args, &)
        Runtime.call(self, args, raise_on_fault: true, &)
      end

      # Per-task settings with lazy parent delegation.
      #
      # @return [Settings]
      #
      # @rbs () -> Settings
      def task_settings
        @task_settings ||= if superclass.respond_to?(:task_settings)
                             superclass.task_settings.for_child
                           else
                             Settings.new
                           end
      end

      # DSL for configuring task settings.
      #
      # @yield [Settings] the settings object
      #
      # @rbs () { (Settings) -> void } -> Settings
      def settings(&block)
        yield(task_settings) if block
        task_settings
      end

      # Task type derived from class name.
      #
      # @return [String]
      #
      # @rbs () -> String
      def type
        Utils::Format.type_name(self)
      end

      # --- Attribute DSL ---

      # @return [AttributeRegistry]
      #
      # @rbs () -> AttributeRegistry
      def attribute_registry
        @attribute_registry ||= if superclass.respond_to?(:attribute_registry)
                                  superclass.attribute_registry.for_child
                                else
                                  AttributeRegistry.new
                                end
      end

      # Declares a required attribute.
      #
      # @param name [Symbol] attribute name
      # @param type [Symbol, nil] coercion type
      # @param options [Hash] attribute options
      #
      # @rbs (Symbol name, ?Symbol? type, **untyped options) -> void
      def required(name, type = nil, **options)
        define_attribute(name, type, required: true, **options)
      end

      # Declares an optional attribute.
      #
      # @param name [Symbol] attribute name
      # @param type [Symbol, nil] coercion type
      # @param options [Hash] attribute options
      #
      # @rbs (Symbol name, ?Symbol? type, **untyped options) -> void
      def optional(name, type = nil, **options)
        define_attribute(name, type, required: false, **options)
      end

      # Generic attribute declaration.
      #
      # @param name [Symbol] attribute name
      # @param type [Symbol, nil] coercion type
      # @param options [Hash] attribute options
      #
      # @rbs (Symbol name, ?Symbol? type, **untyped options) -> void
      def attribute(name, type = nil, **options)
        define_attribute(name, type, **options)
      end

      # Removes an attribute.
      #
      # @param name [Symbol] attribute name
      #
      # @rbs (Symbol name) -> void
      def remove_attribute(name)
        attribute_registry.deregister(name)
      end

      # Returns the schema for all declared attributes.
      #
      # @return [Hash{Symbol => Hash}]
      #
      # @rbs () -> Hash[Symbol, Hash[Symbol, untyped]]
      def attributes_schema
        attribute_registry.schema
      end

      # --- Callback DSL ---

      # @return [CallbackRegistry]
      #
      # @rbs () -> CallbackRegistry
      def callback_registry
        @callback_registry ||= if superclass.respond_to?(:callback_registry)
                                 superclass.callback_registry.for_child
                               else
                                 CallbackRegistry.new
                               end
      end

      CallbackRegistry::TYPES.each do |callback_type|
        define_method(callback_type) do |callable = nil, **options, &block|
          callback_registry.register(callback_type, callable || block, **options)
        end
      end

      # --- Middleware DSL ---

      # @return [MiddlewareRegistry]
      #
      # @rbs () -> MiddlewareRegistry
      def middleware_registry
        @middleware_registry ||= if superclass.respond_to?(:middleware_registry)
                                   superclass.middleware_registry.for_child
                                 else
                                   MiddlewareRegistry.new
                                 end
      end

      # Registers middleware for this task.
      #
      # @param klass [Class] the middleware class
      # @param args [Array] arguments for the middleware
      #
      # @rbs (untyped klass, *untyped args) -> void
      def register(klass, *args)
        middleware_registry.register(klass, *args)
      end

      # Removes middleware from this task.
      #
      # @param klass [Class] the middleware class
      #
      # @rbs (untyped klass) -> void
      def deregister(klass)
        middleware_registry.deregister(klass)
      end

      # --- Returns DSL ---

      # @return [Hash{Symbol => Hash}]
      #
      # @rbs () -> Hash[Symbol, Hash[Symbol, untyped]]
      def returns_registry
        @returns_registry ||= if superclass.respond_to?(:returns_registry)
                                superclass.returns_registry.dup
                              else
                                {}
                              end
      end

      # Declares an expected return key in the context.
      #
      # @param name [Symbol] the context key
      # @param options [Hash] options (:if, :unless)
      #
      # @rbs (Symbol name, **untyped options) -> void
      def returns(name, **options)
        returns_registry[name.to_sym] = options
      end

      # Removes a return declaration.
      #
      # @param name [Symbol] the context key
      #
      # @rbs (Symbol name) -> void
      def remove_returns(name)
        returns_registry.delete(name.to_sym)
      end

      # --- Inheritance hook ---

      private

      # @rbs (Symbol name, Symbol? type, **untyped options) -> void
      def define_attribute(name, type = nil, **options)
        attr_def = Attribute.new(name, type, **options)
        attribute_registry.register(attr_def)
        attribute_registry.define_readers!(self)
      end

      public

      # @rbs (untyped subclass) -> void
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@task_settings, task_settings.for_child)
        subclass.instance_variable_set(:@attribute_registry, attribute_registry.for_child)
        subclass.instance_variable_set(:@callback_registry, callback_registry.for_child)
        subclass.instance_variable_set(:@middleware_registry, middleware_registry.for_child)
        subclass.instance_variable_set(:@returns_registry, returns_registry.dup)
        attribute_registry.define_readers!(subclass)
      end

    end

    private

    # @return [Hash{Symbol => Object}] backing store for attribute accessors
    attr_reader :_attributes

    # @rbs () -> Logger
    def resolve_logger
      s = self.class.task_settings
      log = s.resolved_logger
      if s.resolved_log_level || s.resolved_log_formatter
        log = log.dup
        log.level = s.resolved_log_level if s.resolved_log_level
        log.formatter = s.resolved_log_formatter if s.resolved_log_formatter
      end
      log
    end

    # @rbs (Symbol method_name, *untyped args, **untyped) ?{ () -> untyped } -> untyped
    def method_missing(method_name, *args, **, &)
      if @_attributes&.key?(method_name)
        @_attributes[method_name]
      else
        super
      end
    end

    # @rbs (Symbol method_name, ?bool include_private) -> bool
    def respond_to_missing?(method_name, include_private = false)
      @_attributes&.key?(method_name) || super
    end

  end
end
