# frozen_string_literal: true

module CMDx
  # Represents a task that can be executed within the CMDx framework.
  # Tasks define attributes, callbacks, and execution logic that can be
  # chained together to form workflows.
  class Task

    extend Forwardable

    attr_reader :attributes, :errors, :id, :context, :result, :chain
    alias ctx context
    alias res result

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
      # @option options [AttributeRegistry] :attributes Registry for task attributes
      # @option options [Boolean] :deprecate Whether the task is deprecated
      # @option options [Array<Symbol>] :tags Tags associated with the task
      #
      # @return [Hash] The merged settings hash
      #
      # @example
      #   class MyTask < Task
      #     settings deprecate: true, tags: [:experimental]
      #   end
      def settings(**options)
        @settings ||= begin
          hash =
            if superclass.respond_to?(:settings)
              superclass.settings
            else
              CMDx.configuration.to_h.except(:logger)
            end.transform_values(&:dup)

          hash[:attributes] ||= AttributeRegistry.new
          hash[:deprecate] ||= false
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
      def attributes(...)
        register(:attribute, Attribute.build(...))
      end
      alias attribute attributes

      # @param args [Array] Arguments to build the optional attribute with
      #
      # @example
      #   optional :description, :notes
      #   optional :priority, type: Symbol, default: :normal
      def optional(...)
        register(:attribute, Attribute.optional(...))
      end

      # @param args [Array] Arguments to build the required attribute with
      #
      # @example
      #   required :name, :email
      #   required :age, type: Integer, min: 0
      def required(...)
        register(:attribute, Attribute.required(...))
      end

      # @param names [Array<Symbol>] Names of attributes to remove
      #
      # @example
      #   remove_attributes :old_field, :deprecated_field
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
      def execute(...)
        task = new(...)
        task.execute(raise: false)
        task.result
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
      def execute!(...)
        task = new(...)
        task.execute(raise: true)
        task.result
      end

    end

    # @param raise [Boolean] Whether to raise exceptions on failure
    #
    # @return [Result] The execution result
    #
    # @example
    #   result = task.execute
    #   result = task.execute(raise: true)
    def execute(raise: false)
      Executor.execute(self, raise:)
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
    def work
      raise UndefinedMethodError, "undefined method #{self.class.name}#work"
    end

    # @return [Logger] The logger instance for this task
    #
    # @example
    #   logger.info "Starting task execution"
    #   logger.error "Task failed", error: exception
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
    def to_s
      Utils::Format.to_str(to_h)
    end

  end
end
