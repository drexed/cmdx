# frozen_string_literal: true

module CMDx
  # Core task execution system for CMDx framework.
  #
  # Task provides the foundational functionality for executing business logic
  # with parameter validation, middleware support, callback execution, and
  # result tracking. Tasks encapsulate reusable business operations with
  # comprehensive error handling, logging, and execution state management.
  class Task

    cmdx_attr_setting :cmd_settings,
                      default: -> { CMDx.configuration.to_h.slice(:logger, :task_halt, :workflow_halt).merge(tags: []) }
    cmdx_attr_setting :cmd_middlewares,
                      default: -> { MiddlewareRegistry.new(CMDx.configuration.middlewares) }
    cmdx_attr_setting :cmd_callbacks,
                      default: -> { CallbackRegistry.new(CMDx.configuration.callbacks) }
    cmdx_attr_setting :cmd_parameters,
                      default: -> { ParameterRegistry.new }

    cmdx_attr_delegator :cmd_middlewares, :cmd_callbacks, :cmd_parameters,
                        :cmd_settings, :cmd_setting, :cmd_setting?,
                        to: :class
    cmdx_attr_delegator :skip!, :fail!, :throw!,
                        to: :result

    # @return [Context] parameter context for this task execution
    attr_reader :context

    # @return [Errors] collection of validation and execution errors
    attr_reader :errors

    # @return [String] unique identifier for this task instance
    attr_reader :id

    # @return [Result] execution result tracking state and status
    attr_reader :result

    # @return [Chain] execution chain containing this task and related executions
    attr_reader :chain

    # @return [Context] alias for context
    alias ctx context

    # @return [Result] alias for result
    alias res result

    # Creates a new task instance with the provided execution context.
    #
    # @param context [Hash, Context] execution context data or Context instance
    #
    # @return [Task] a new task instance ready for execution
    #
    # @example Create a task with hash context
    #   task = MyTask.new(user_id: 123, action: "process")
    #   task.context.user_id #=> 123
    #
    # @example Create a task with existing context
    #   existing_context = CMDx::Context.build(name: "John")
    #   task = MyTask.new(existing_context)
    #   task.context.name #=> "John"
    def initialize(context = {})
      TaskDeprecator.call(self)

      context  = context.context if context.respond_to?(:context)

      @context = Context.build(context)
      @errors  = Errors.new
      @id      = CMDx::Correlator.generate
      @result  = Result.new(self)
      @chain   = Chain.build(@result)
    end

    class << self

      # Registers callbacks for task execution lifecycle events.
      #
      # These methods are dynamically defined for each callback type and provide
      # a clean DSL for registering callbacks that will be executed at specific
      # points during task execution.
      #
      # @param callables [Array<Object>] callback objects to register (symbols, procs, classes)
      # @param options [Hash] conditional execution options
      # @param block [Proc] optional block to register as a callback
      #
      # @return [void]
      #
      # @example Register before_execution callback with symbol
      #   MyTask.before_execution :setup_database
      #
      # @example Register before_execution callback with proc
      #   MyTask.before_execution -> { puts "Starting task execution" }
      #
      # @example Register before_execution callback with class
      #   MyTask.before_execution SetupCallback
      #
      # @example Register before_execution callback with block
      #   MyTask.before_execution { |task| task.context.started_at = Time.now }
      #
      # @example Register on_success callback with conditional options
      #   MyTask.on_success :send_notification, if: -> { Rails.env.production? }
      #
      # @example Register on_success callback with multiple callables
      #   MyTask.on_success :log_success, :send_email, :update_metrics
      CallbackRegistry::TYPES.each do |callback|
        define_method(callback) do |*callables, **options, &block|
          cmd_callbacks.register(callback, *callables, **options, &block)
        end
      end

      # Retrieves the value of a task setting.
      #
      # @param key [Symbol] the setting key to retrieve
      #
      # @return [Object] the setting value, processed through cmdx_yield
      #
      # @example Get logger setting
      #   MyTask.cmd_setting(:logger) #=> #<Logger:...>
      #
      # @example Get halt setting
      #   MyTask.cmd_setting(:task_halt) #=> "failed"
      def cmd_setting(key)
        cmdx_yield(cmd_settings[key])
      end

      # Checks if a task setting key exists.
      #
      # @param key [Symbol] the setting key to check
      #
      # @return [Boolean] true if the setting exists, false otherwise
      #
      # @example Check if setting exists
      #   MyTask.cmd_setting?(:logger) #=> true
      #   MyTask.cmd_setting?(:invalid) #=> false
      def cmd_setting?(key)
        cmd_settings.key?(key)
      end

      # Updates task settings with new values.
      #
      # @param options [Hash] hash of setting keys and values to merge
      #
      # @return [Hash] the updated task settings hash
      #
      # @example Update task settings
      #   MyTask.cmd_settings!(task_halt: ["failed", "error"])
      #   MyTask.cmd_setting(:task_halt) #=> ["failed", "error"]
      def cmd_settings!(**options)
        cmd_settings.merge!(options)
      end

      # Registers middleware, callbacks, validators, or coercions with the task.
      #
      # @param type [Symbol] the type of registration (:middleware, :callback, :validator, :coercion)
      # @param object [Object] the object to register
      # @param args [Array] additional arguments passed to the registration method
      #
      # @return [void]
      #
      # @example Register middleware
      #   MyTask.use(:middleware, TimeoutMiddleware, timeout: 30)
      #
      # @example Register callback
      #   MyTask.use(:callback, :before_execution, MyCallback)
      def use(type, object, ...)
        case type
        when :middleware
          cmd_middlewares.register(object, ...)
        when :callback
          cmd_callbacks.register(type, object, ...)
        when :validator
          cmd_validators.register(type, object, ...)
        when :coercion
          cmd_coercions.register(type, object, ...)
        end
      end

      # Defines optional parameters for the task.
      #
      # @param attributes [Array<Symbol>] parameter names to define as optional
      # @param options [Hash] parameter configuration options
      # @param block [Proc] optional block for defining nested parameters
      #
      # @return [void]
      #
      # @example Define optional parameters
      #   MyTask.optional :name, :email, type: :string
      #
      # @example Define optional parameter with validation
      #   MyTask.optional :age, type: :integer, validate: { numeric: { greater_than: 0 } }
      def optional(*attributes, **options, &)
        parameters = Parameter.optional(*attributes, **options.merge(klass: self), &)
        cmd_parameters.registry.concat(parameters)
      end

      # Defines required parameters for the task.
      #
      # @param attributes [Array<Symbol>] parameter names to define as required
      # @param options [Hash] parameter configuration options
      # @param block [Proc] optional block for defining nested parameters
      #
      # @return [void]
      #
      # @example Define required parameters
      #   MyTask.required :user_id, :action, type: :string
      #
      # @example Define required parameter with nested structure
      #   MyTask.required :user, type: :hash do
      #     required :name, type: :string
      #     optional :email, type: :string
      #   end
      def required(*attributes, **options, &)
        parameters = Parameter.required(*attributes, **options.merge(klass: self), &)
        cmd_parameters.registry.concat(parameters)
      end

      # Executes the task with fault tolerance and returns the result.
      #
      # @param args [Array] arguments passed to the task constructor
      #
      # @return [Result] the task execution result
      #
      # @example Execute task with fault tolerance
      #   result = MyTask.call(user_id: 123)
      #   result.success? #=> true
      #   result.context.user_id #=> 123
      def call(...)
        instance = new(...)
        instance.process
        instance.result
      end

      # Executes the task with strict fault handling and returns the result.
      #
      # @param args [Array] arguments passed to the task constructor
      #
      # @return [Result] the task execution result
      #
      # @raise [Fault] if the task fails and task_halt setting includes the failure status
      #
      # @example Execute task with strict fault handling
      #   result = MyTask.call!(user_id: 123)
      #   result.success? #=> true
      #
      # @example Handling fault on failure
      #   begin
      #     MyTask.call!(invalid_data: true)
      #   rescue CMDx::Fault => e
      #     puts "Task failed: #{e.message}"
      #   end
      def call!(...)
        instance = new(...)
        instance.process!
        instance.result
      end

    end

    # Abstract method that must be implemented by task subclasses.
    #
    # This method contains the core business logic to be executed by the task.
    # Subclasses must override this method to provide their specific implementation.
    #
    # @return [void]
    #
    # @raise [UndefinedCallError] if not implemented by subclass
    #
    # @example Implement in a subclass
    #   class ProcessUserTask < CMDx::Task
    #     def call
    #       # Business logic here
    #       context.processed = true
    #     end
    #   end
    def call
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

    # Performs task execution with middleware support and fault tolerance.
    #
    # @return [void]
    #
    # @example Task execution with middleware
    #   task = MyTask.new(user_id: 123)
    #   task.process
    #   task.result.success? #=> true
    def process
      cmd_middlewares.call(self) { |task| TaskProcessor.call(task) }
    end

    # Performs task execution with middleware support and strict fault handling.
    #
    # @return [void]
    #
    # @raise [Fault] if task fails and task_halt setting includes the failure status
    #
    # @example Task execution with strict fault handling
    #   task = MyTask.new(user_id: 123)
    #   task.process!
    #   task.result.success? #=> true
    def process!
      cmd_middlewares.call(self) { |task| TaskProcessor.call!(task) }
    end

    private

    # Creates a logger instance for this task.
    #
    # @return [Logger] logger instance configured for this task
    #
    # @example Getting task logger
    #   task = MyTask.new
    #   logger = task.send(:logger)
    #   logger.info("Task started")
    def logger
      Logger.call(self)
    end

  end
end
