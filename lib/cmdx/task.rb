# frozen_string_literal: true

module CMDx
  # Represents a task that can be executed within the CMDx framework.
  # Tasks define attributes, callbacks, and execution logic that can be
  # chained together to form workflows.
  class Task

    extend Forwardable

    # @rbs @attributes: Hash[Symbol, untyped]
    attr_reader :attributes

    # @rbs @errors: Errors
    attr_reader :errors

    # @rbs @id: String
    attr_reader :id

    # @rbs @context: Context
    attr_reader :context
    alias ctx context

    # @rbs @result: Result
    attr_reader :result
    alias res result

    # @rbs @chain: Chain
    attr_reader :chain

    def_delegators :result, :skip!, :fail!, :throw!

    # @param context [Hash, Context] The initial context for the task
    #
    # @option context [Object] :* Any key-value pairs to initialize the context
    #
    # @return [Task] A new task instance
    #
    # @raise [DeprecationError] If the task class is deprecated
    #
    # @example
    #   task = MyTask.new(name: "example", priority: :high)
    #   task = MyTask.new(Context.build(name: "example"))
    #
    # @rbs (untyped context) -> void
    def initialize(context = {})
      Deprecator.restrict(self)

      @attributes = {}
      @errors = Errors.new

      @id = Identifier.generate
      @context = Context.build(context)
      @result = Result.new(self)
      @chain = Chain.build(@result)
    end

    class << self

      # @param options [Hash] Configuration options to merge with existing settings
      #
      # @return [Hash] The merged settings hash
      #
      # @example
      #   class MyTask < Task
      #     settings deprecate: true, tags: [:experimental]
      #   end
      #
      # @rbs (**untyped options) -> Hash[Symbol, untyped]
      def settings(**options)
        @settings ||= begin
          hash =
            if superclass.respond_to?(:settings)
              parent = superclass.settings
              parent
                .except(:backtrace_cleaner, :exception_handler, :logger, :deprecate)
                .transform_values!(&:dup)
                .merge!(
                  backtrace_cleaner: parent[:backtrace_cleaner] || CMDx.configuration.backtrace_cleaner,
                  exception_handler: parent[:exception_handler] || CMDx.configuration.exception_handler,
                  logger: parent[:logger] || CMDx.configuration.logger,
                  deprecate: parent[:deprecate]
                )
            else
              CMDx.configuration.to_h
            end

          hash[:attributes] ||= AttributeRegistry.new
          hash[:tags] ||= []

          hash.merge!(options)
        end
      end

      # @param type [Symbol] The type of registry to register with
      # @param object [Object] The object to register
      # @param args [Array] Additional arguments for registration
      #
      # @raise [RuntimeError] If the registry type is unknown
      #
      # @example
      #   register(:attribute, MyAttribute.new)
      #   register(:callback, :before, -> { puts "before" })
      #
      # @rbs (Symbol type, untyped object, *untyped) -> void
      def register(type, object, ...)
        case type
        when :attribute then settings[:attributes].register(object, ...)
        when :callback then settings[:callbacks].register(object, ...)
        when :coercion then settings[:coercions].register(object, ...)
        when :middleware then settings[:middlewares].register(object, ...)
        when :validator then settings[:validators].register(object, ...)
        else raise "unknown registry type #{type.inspect}"
        end
      end

      # @param type [Symbol] The type of registry to deregister from
      # @param object [Object] The object to deregister
      # @param args [Array] Additional arguments for deregistration
      #
      # @raise [RuntimeError] If the registry type is unknown
      #
      # @example
      #   deregister(:attribute, :name)
      #   deregister(:callback, :before, MyCallback)
      #
      # @rbs (Symbol type, untyped object, *untyped) -> void
      def deregister(type, object, ...)
        case type
        when :attribute then settings[:attributes].deregister(object, ...)
        when :callback then settings[:callbacks].deregister(object, ...)
        when :coercion then settings[:coercions].deregister(object, ...)
        when :middleware then settings[:middlewares].deregister(object, ...)
        when :validator then settings[:validators].deregister(object, ...)
        else raise "unknown registry type #{type.inspect}"
        end
      end

      # @param args [Array] Arguments to build the attribute with
      #
      # @example
      #   attributes :name, :email
      #   attributes :age, type: Integer, default: 18
      #
      # @rbs (*untyped) -> void
      def attributes(...)
        register(:attribute, Attribute.build(...))
      end
      alias attribute attributes

      # @param args [Array] Arguments to build the optional attribute with
      #
      # @example
      #   optional :description, :notes
      #   optional :priority, type: Symbol, default: :normal
      #
      # @rbs (*untyped) -> void
      def optional(...)
        register(:attribute, Attribute.optional(...))
      end

      # @param args [Array] Arguments to build the required attribute with
      #
      # @example
      #   required :name, :email
      #   required :age, type: Integer, min: 0
      #
      # @rbs (*untyped) -> void
      def required(...)
        register(:attribute, Attribute.required(...))
      end

      # @param names [Array<Symbol>] Names of attributes to remove
      #
      # @example
      #   remove_attributes :old_field, :deprecated_field
      #
      # @rbs (*Symbol names) -> void
      def remove_attributes(*names)
        deregister(:attribute, names)
      end
      alias remove_attribute remove_attributes

      CallbackRegistry::TYPES.each do |callback|
        # @param callables [Array] Callable objects to register as callbacks
        # @param options [Hash] Options for the callback registration
        # @option options [Symbol] :priority Priority of the callback
        # @option options [Boolean] :async Whether the callback should run asynchronously
        # @param block [Proc] Block to register as a callback
        #
        # @example
        #   before { puts "before execution" }
        #   after :cleanup, priority: :high
        #   around ->(task) { task.logger.info("starting") }
        #
        # @rbs (*untyped callables, **untyped options) ?{ () -> void } -> void
        define_method(callback) do |*callables, **options, &block|
          register(:callback, callback, *callables, **options, &block)
        end
      end

      # @param args [Array] Arguments to pass to the task constructor
      #
      # @return [Result] The execution result
      #
      # @example
      #   result = MyTask.execute(name: "example")
      #   if result.success?
      #     puts "Task completed successfully"
      #   end
      #
      # @rbs (*untyped args, **untyped kwargs) ?{ (Result) -> void } -> Result
      def execute(*args, **kwargs)
        task = new(*args, **kwargs)
        task.execute(raise: false)
        block_given? ? yield(task.result) : task.result
      end

      # @param args [Array] Arguments to pass to the task constructor
      #
      # @return [Result] The execution result
      #
      # @raise [ExecutionError] If the task execution fails
      #
      # @example
      #   result = MyTask.execute!(name: "example")
      #   # Will raise an exception if execution fails
      #
      # @rbs (*untyped args, **untyped kwargs) ?{ (Result) -> void } -> Result
      def execute!(*args, **kwargs)
        task = new(*args, **kwargs)
        task.execute(raise: true)
        block_given? ? yield(task.result) : task.result
      end

    end

    # @param raise [Boolean] Whether to raise exceptions on failure
    #
    # @return [Result] The execution result
    #
    # @example
    #   result = task.execute
    #   result = task.execute(raise: true)
    #
    # @rbs (raise: bool) ?{ (Result) -> void } -> Result
    def execute(raise: false)
      Executor.execute(self, raise:)
      block_given? ? yield(result) : result
    end

    # @raise [UndefinedMethodError] Always raised as this method must be overridden
    #
    # @example
    #   class MyTask < Task
    #     def work
    #       # Custom work logic here
    #       puts "Performing work..."
    #     end
    #   end
    #
    # @rbs () -> void
    def work
      raise UndefinedMethodError, "undefined method #{self.class.name}#work"
    end

    # @return [Logger] The logger instance for this task
    #
    # @example
    #   logger.info "Starting task execution"
    #   logger.error "Task failed", error: exception
    #
    # @rbs () -> Logger
    def logger
      @logger ||= begin
        logger = self.class.settings[:logger] || CMDx.configuration.logger
        logger.level = self.class.settings[:log_level] || logger.level
        logger.formatter = self.class.settings[:log_formatter] || logger.formatter
        logger
      end
    end

    # @return [Hash] A hash representation of the task
    #
    # @option return [Integer] :index The result index
    # @option return [String] :chain_id The chain identifier
    # @option return [String] :type The task type ("Task" or "Workflow")
    # @option return [Array<Symbol>] :tags The task tags
    # @option return [String] :class The task class name
    # @option return [String] :id The task identifier
    #
    # @example
    #   task_hash = task.to_h
    #   puts "Task type: #{task_hash[:type]}"
    #   puts "Task tags: #{task_hash[:tags].join(', ')}"
    #
    # @rbs () -> Hash[Symbol, untyped]
    def to_h
      {
        index: result.index,
        chain_id: chain.id,
        type: self.class.include?(Workflow) ? "Workflow" : "Task",
        tags: self.class.settings[:tags],
        class: self.class.name,
        id:
      }
    end

    # @return [String] A string representation of the task
    #
    # @example
    #   puts task.to_s
    #   # Output: "Task[MyTask] tags: [:important] id: abc123"
    #
    # @rbs () -> String
    def to_s
      Utils::Format.to_str(to_h)
    end

  end
end
