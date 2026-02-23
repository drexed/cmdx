# frozen_string_literal: true

module CMDx
  # Represents a task that can be executed within the CMDx framework.
  # Tasks define attributes, callbacks, and execution logic that can be
  # chained together to form workflows.
  class Task

    extend Forwardable

    # Returns the hash of processed attribute values for this task.
    #
    # @return [Hash{Symbol => Object}] Hash of attribute names to their values
    #
    # @example
    #   task.attributes # => { user_id: 42, user_name: "John" }
    #
    # @rbs @attributes: Hash[Symbol, untyped]
    attr_reader :attributes

    # Returns the collection of validation and execution errors.
    #
    # @return [Errors] The errors collection
    #
    # @example
    #   task.errors.to_h # => { email: ["must be valid"] }
    #
    # @rbs @errors: Errors
    attr_reader :errors

    # Returns the unique identifier for this task instance.
    #
    # @return [String] The task identifier
    #
    # @example
    #   task.id # => "abc123xyz"
    #
    # @rbs @id: String
    attr_reader :id

    # Returns the execution context for this task.
    #
    # @return [Context] The context instance
    #
    # @example
    #   task.context[:user_id] # => 42
    #
    # @rbs @context: Context
    attr_reader :context
    alias ctx context

    # Returns the execution result for this task.
    #
    # @return [Result] The result instance
    #
    # @example
    #   task.result.status # => "success"
    #
    # @rbs @result: Result
    attr_reader :result
    alias res result

    # Returns the execution chain containing all task results.
    #
    # @return [Chain] The chain instance
    #
    # @example
    #   task.chain.results.size # => 3
    #
    # @rbs @chain: Chain
    attr_reader :chain

    def_delegators :result, :skip!, :fail!, :throw!
    def_delegators :chain, :dry_run?

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
      @chain = Chain.build(@result, dry_run: @context.delete(:dry_run))
    end

    class << self

      # @param options [Hash] Configuration options to merge with existing settings
      # @option options [Object] :* Any configuration option key-value pairs
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
          hash[:returns] ||= []
          hash[:tags] ||= []

          hash.merge!(options)
        end
      end

      # @param type [Symbol] The type of registry to register with
      # @param object [Object] The object to register
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

      # @example
      #   attributes :name, :email
      #   attributes :age, type: Integer, default: 18
      #
      # @rbs (*untyped) -> void
      def attributes(...)
        register(:attribute, Attribute.build(...))
      end
      alias attribute attributes

      # @example
      #   optional :description, :notes
      #   optional :priority, type: Symbol, default: :normal
      #
      # @rbs (*untyped) -> void
      def optional(...)
        register(:attribute, Attribute.optional(...))
      end

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

      # Declares expected context returns that must be set after task execution.
      # If any declared return is missing from the context after {#work} completes
      # successfully, the task will fail with a validation error.
      #
      # @param names [Array<Symbol, String>] Names of expected return keys in the context
      #
      # @example
      #   returns :user, :token
      #
      # @rbs (*untyped names) -> void
      def returns(*names)
        settings[:returns] |= names.map(&:to_sym)
      end

      # Removes declared returns from the task.
      #
      # @param names [Array<Symbol>] Names of returns to remove
      #
      # @example
      #   remove_returns :old_return
      #
      # @rbs (*Symbol names) -> void
      def remove_returns(*names)
        settings[:returns] -= names.map(&:to_sym)
      end
      alias remove_return remove_returns

      # @return [Hash] Hash of attribute names to their configurations
      #
      # @example
      #   MyTask.attributes_schema #=> {
      #     user_id: { name: :user_id, method_name: :user_id, required: true, types: [:integer], options: {}, children: [] },
      #     email: { name: :email, method_name: :email, required: false, types: [:string], options: { default: nil }, children: [] },
      #     profile: { name: :profile, method_name: :profile, required: false, types: [:hash], options: {}, children: [
      #       { name: :bio, method_name: :bio, required: false, types: [:string], options: {}, children: [] },
      #       { name: :name, method_name: :name, required: true, types: [:string], options: {}, children: [] }
      #     ] }
      #   }
      #
      # @rbs () -> Hash[Symbol, Hash[Symbol, untyped]]
      def attributes_schema
        Array(settings[:attributes]).each_with_object({}) do |attr, schema|
          schema[attr.method_name] = attr.to_h
        end
      end

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
      # @param kwargs [Hash] Keyword arguments to pass to the task constructor
      # @option kwargs [Object] :* Any key-value pairs to pass to the task constructor
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
      # @param kwargs [Hash] Keyword arguments to pass to the task constructor
      # @option kwargs [Object] :* Any key-value pairs to pass to the task constructor
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

    # @option return [Integer] :index The result index
    # @option return [String] :chain_id The chain identifier
    # @option return [String] :type The task type ("Task" or "Workflow")
    # @option return [Array<Symbol>] :tags The task tags
    # @option return [String] :class The task class name
    # @option return [String] :id The task identifier
    #
    # @return [Hash] A hash representation of the task
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
        dry_run: dry_run?,
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
