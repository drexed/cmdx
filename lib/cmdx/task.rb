# frozen_string_literal: true

module CMDx
  # Core task implementation providing executable units of work with parameter management.
  #
  # Task is the fundamental building block of the CMDx framework, providing a structured
  # approach to implementing business logic with built-in parameter validation, middleware
  # support, callback handling, and comprehensive result tracking. Tasks encapsulate
  # discrete units of work that can be chained together into workflows or executed
  # independently with rich execution context and error handling.
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

    # Creates a new task instance with the given execution context.
    #
    # Initializes all internal state including context, errors, unique identifier,
    # result tracking, and execution chain. The context parameter supports various
    # input formats and will be normalized into a Context instance.
    #
    # @param context [Hash, Context, Object] initial execution context and parameters
    #
    # @return [Task] the newly created task instance
    #
    # @example Create task with hash context
    #   task = MyTask.new(user_id: 123, action: "process")
    #   task.context.user_id #=> 123
    #
    # @example Create task with existing context
    #   existing_context = OtherTask.call(status: "active")
    #   task = MyTask.new(existing_context)
    #   task.context.status #=> "active"
    #
    # @example Create task with empty context
    #   task = MyTask.new
    #   task.context #=> empty Context instance
    def initialize(context = {})
      context  = context.context if context.respond_to?(:context)

      @context = Context.build(context)
      @errors  = Errors.new
      @id      = CMDx::Correlator.generate
      @result  = Result.new(self)
      @chain   = Chain.build(@result)

      TaskDeprecator.call(self)
    end

    class << self

      CallbackRegistry::TYPES.each do |callback|
        # Registers a callback for the specified lifecycle event.
        #
        # This method is dynamically defined for each callback type supported by
        # CallbackRegistry, allowing tasks to register callbacks for various
        # execution lifecycle events.
        #
        # @param callables [Array<Object>] callback objects or procs to register
        # @param options [Hash] options for callback registration
        # @param block [Proc] optional block to use as callback
        #
        # @return [void]
        #
        # @example Register before_execution callback with symbol
        #   class MyTask < CMDx::Task
        #     before_execution :setup_database
        #   end
        #
        # @example Register before_execution callback with proc
        #   class MyTask < CMDx::Task
        #     before_execution -> { puts "Starting task execution" }
        #   end
        #
        # @example Register before_execution callback with class
        #   class MyTask < CMDx::Task
        #     before_execution SetupCallback
        #   end
        #
        # @example Register before_execution callback with block
        #   class MyTask < CMDx::Task
        #     before_execution { |task| task.context.started_at = Time.now }
        #   end
        #
        # @example Register on_success callback with conditional options
        #   class MyTask < CMDx::Task
        #     on_success :send_notification, if: -> { Rails.env.production? }
        #   end
        #
        # @example Register on_success callback with multiple callables
        #   class MyTask < CMDx::Task
        #     on_success :log_success, :send_email, :update_metrics
        #   end
        define_method(callback) do |*callables, **options, &block|
          cmd_callbacks.register(callback, *callables, **options, &block)
        end
      end

      # Retrieves a configuration setting value by key.
      #
      # Provides access to task-specific configuration settings that control
      # various aspects of task execution including logging, halt conditions,
      # and custom settings.
      #
      # @param key [Symbol, String] the configuration setting key to retrieve
      #
      # @return [Object] the configuration value, or nil if key doesn't exist
      #
      # @example Get logger setting
      #   MyTask.cmd_setting(:logger) #=> Logger instance
      #
      # @example Get custom setting
      #   MyTask.cmd_settings!(timeout: 30)
      #   MyTask.cmd_setting(:timeout) #=> 30
      def cmd_setting(key)
        cmdx_yield(cmd_settings[key])
      end

      # Checks if a configuration setting exists.
      #
      # @param key [Symbol, String] the configuration setting key to check
      #
      # @return [Boolean] true if the setting key exists, false otherwise
      #
      # @example Check for existing setting
      #   MyTask.cmd_setting?(:logger) #=> true
      #
      # @example Check for non-existing setting
      #   MyTask.cmd_setting?(:nonexistent) #=> false
      def cmd_setting?(key)
        cmd_settings.key?(key)
      end

      # Updates task configuration settings with the provided options.
      #
      # Merges the given options into the existing configuration settings,
      # allowing tasks to customize their execution behavior.
      #
      # @param options [Hash] configuration options to merge
      #
      # @return [Hash] the updated settings hash
      #
      # @example Set custom timeout
      #   MyTask.cmd_settings!(timeout: 60, retries: 3)
      #
      # @example Override halt condition
      #   MyTask.cmd_settings!(task_halt: ["failed", "error"])
      def cmd_settings!(**options)
        cmd_settings.merge!(options)
      end

      # Registers middleware, callbacks, validators, or coercions with the task.
      #
      # Provides a unified interface for registering various types of task
      # extensions that modify or enhance task execution behavior.
      #
      # @param type [Symbol] the type of extension to register (:middleware, :callback, :validator, :coercion)
      # @param object [Object] the extension object to register
      # @param args [Array] additional arguments for registration
      #
      # @return [void]
      #
      # @raise [ArgumentError] if an unsupported type is provided
      #
      # @example Register coercion
      #   class MyTask < CMDx::Task
      #     use :coercion, TemperatureCoercion
      #   end
      #
      # @example Register validator
      #   class MyTask < CMDx::Task
      #     use :validator, ZipcodeValidator, country: "US"
      #   end
      #
      # @example Register middleware
      #   class MyTask < CMDx::Task
      #     use :middleware, CMDx::Middlewares::Timeout.new(seconds: 30)
      #   end
      #
      # @example Register callback
      #   class MyTask < CMDx::Task
      #     use :callback, :before, LogCallback.new
      #   end
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

      # Defines optional parameters for the task with validation and coercion.
      #
      # Creates parameter definitions that are not required for task execution
      # but will be validated and coerced if provided. Supports nested parameter
      # structures through block syntax.
      #
      # @param attributes [Array<Symbol>] parameter names to define as optional
      # @param options [Hash] parameter configuration options
      # @option options [Symbol, Array<Symbol>] :type parameter type(s) for coercion
      # @option options [Object] :default default value if parameter not provided
      # @option options [Hash] :validates validation rules to apply
      # @param block [Proc] optional block for defining nested parameters
      #
      # @return [Array<Parameter>] the created parameter definitions
      #
      # @example Define simple optional parameters
      #   class MyTask < CMDx::Task
      #     optional :name, :email, type: :string
      #     optional :age, type: :integer, default: 0
      #   end
      #
      # @example Define optional parameter with validation
      #   class MyTask < CMDx::Task
      #     optional :score, type: :integer, validates: { numeric: { greater_than: 0 } }
      #   end
      #
      # @example Define nested optional parameters
      #   class MyTask < CMDx::Task
      #     optional :user, type: :hash do
      #       required :name, type: :string
      #       optional :age, type: :integer
      #     end
      #   end
      def optional(*attributes, **options, &)
        parameters = Parameter.optional(*attributes, **options.merge(klass: self), &)
        cmd_parameters.registry.concat(parameters)
      end

      # Defines required parameters for the task with validation and coercion.
      #
      # Creates parameter definitions that must be provided for successful task
      # execution. Missing required parameters will cause task validation to fail.
      # Supports nested parameter structures through block syntax.
      #
      # @param attributes [Array<Symbol>] parameter names to define as required
      # @param options [Hash] parameter configuration options
      # @option options [Symbol, Array<Symbol>] :type parameter type(s) for coercion
      # @option options [Object] :default default value if parameter not provided
      # @option options [Hash] :validates validation rules to apply
      # @param block [Proc] optional block for defining nested parameters
      #
      # @return [Array<Parameter>] the created parameter definitions
      #
      # @example Define simple required parameters
      #   class MyTask < CMDx::Task
      #     required :user_id, type: :integer
      #     required :action, type: :string
      #   end
      #
      # @example Define required parameter with validation
      #   class MyTask < CMDx::Task
      #     required :email, type: :string, validates: { format: /@/ }
      #   end
      #
      # @example Define nested required parameters
      #   class MyTask < CMDx::Task
      #     required :payment, type: :hash do
      #       required :amount, type: :big_decimal
      #       required :currency, type: :string
      #       optional :description, type: :string
      #     end
      #   end
      def required(*attributes, **options, &)
        parameters = Parameter.required(*attributes, **options.merge(klass: self), &)
        cmd_parameters.registry.concat(parameters)
      end

      # Executes a task instance and returns the result without raising exceptions.
      #
      # Creates a new task instance with the provided context, processes it through
      # the complete execution pipeline, and returns the result. This method will
      # not raise exceptions for task failures but will capture them in the result.
      #
      # @param args [Array] arguments passed to task constructor
      #
      # @return [Result] the execution result containing state, status, and metadata
      #
      # @example Execute task
      #   result = MyTask.call(user_id: 123, action: "process")
      #   puts result.status #=> "success" or "failed" or "skipped"
      def call(...)
        instance = new(...)
        instance.process
        instance.result
      end

      # Executes a task instance and returns the result, raising exceptions on failure.
      #
      # Creates a new task instance with the provided context, processes it through
      # the complete execution pipeline, and returns the result. This method will
      # raise appropriate fault exceptions if the task fails or is skipped.
      #
      # @param args [Array] arguments passed to task constructor
      #
      # @return [Result] the execution result containing state, status, and metadata
      #
      # @raise [Failed] when task execution fails
      # @raise [Skipped] when task execution is skipped
      #
      # @example Execute task
      #   begin
      #     result = MyTask.call!(user_id: 123)
      #     puts "Success: #{result.status}"
      #   rescue CMDx::Failed => e
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
    # This method contains the actual business logic for the task. Subclasses
    # must override this method to provide their specific implementation.
    # The method has access to the task's context, can modify it, and can
    # use skip!, fail!, or throw! to control execution flow.
    #
    # @return [void]
    #
    # @raise [UndefinedCallError] always raised in the base Task class
    #
    # @example Implement in a subclass
    #   class ProcessUserTask < CMDx::Task
    #     required :user_id, type: :integer
    #
    #     def call
    #       user = User.find(context.user_id)
    #       skip!(reason: "User already processed") if user.processed?
    #
    #       user.process!
    #       context.processed_at = Time.now
    #     end
    #   end
    def call
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

    # Executes the task through the middleware pipeline without raising exceptions.
    #
    # Processes the task by running it through all registered middleware and
    # the TaskProcessor. This method captures exceptions and converts them
    # into result states rather than propagating them.
    #
    # @return [void]
    #
    # @example Process a task instance
    #   task = MyTask.new(data: "input")
    #   task.process
    #   puts task.result.status #=> "success", "failed", or "skipped"
    def process
      cmd_middlewares.call(self) { |task| TaskProcessor.call(task) }
    end

    # Executes the task through the middleware pipeline, raising exceptions on failure.
    #
    # Processes the task by running it through all registered middleware and
    # the TaskProcessor. This method will raise appropriate fault exceptions
    # if the task fails or is skipped.
    #
    # @return [void]
    #
    # @raise [Failed] when task execution fails
    # @raise [Skipped] when task execution is skipped
    #
    # @example Process a task instance with exception handling
    #   task = RiskyTask.new(data: "input")
    #   begin
    #     task.process!
    #     puts "Task completed successfully"
    #   rescue CMDx::Failed => e
    #     puts "Task failed: #{e.message}"
    #   end
    def process!
      cmd_middlewares.call(self) { |task| TaskProcessor.call!(task) }
    end

    # Creates a logger instance configured for this task.
    #
    # Returns a logger instance that is pre-configured with the task's
    # settings and context information for consistent logging throughout
    # task execution.
    #
    # @return [Logger] configured logger instance for this task
    #
    # @example Log task execution
    #   def call
    #     logger.info "Starting user processing"
    #     # ... task logic ...
    #     logger.info "User processing completed"
    #   end
    def logger
      Logger.call(self)
    end

  end
end
