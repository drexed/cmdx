# frozen_string_literal: true

module CMDx
  ##
  # Task is the base class for all command objects in CMDx, providing a framework
  # for encapsulating business logic with parameter validation, callbacks, and result tracking.
  #
  # Tasks follow a single-use pattern where each instance can only be executed once,
  # after which it becomes frozen and immutable. This ensures predictable execution
  # and prevents side effects from multiple calls.
  #
  # @example Basic task definition
  #   class ProcessOrderTask < CMDx::Task
  #     required :order_id, type: :integer
  #     optional :notify_user, type: :boolean, default: true
  #
  #     def call
  #       # Business logic here
  #       context.order = Order.find(order_id)
  #       skip!(reason: "Order already processed") if context.order.processed?
  #
  #       context.order.process!
  #       NotificationService.call(order_id: order_id) if notify_user
  #     end
  #   end
  #
  # @example Task execution
  #   result = ProcessOrderTask.call(order_id: 123, notify_user: false)
  #   result.success? #=> true
  #   result.context.order #=> <Order id: 123>
  #
  # @example Task chaining with Result objects
  #   # First task extracts data
  #   class ExtractDataTask < CMDx::Task
  #     required :source_id, type: :integer
  #
  #     def call
  #       context.extracted_data = DataSource.extract(source_id)
  #       context.extraction_time = Time.now
  #     end
  #   end
  #
  #   # Second task processes the extracted data
  #   class ProcessDataTask < CMDx::Task
  #     def call
  #       # Access data from previous task's context
  #       fail!(reason: "No data to process") unless context.extracted_data
  #
  #       context.processed_data = DataProcessor.process(context.extracted_data)
  #       context.processing_time = Time.now
  #     end
  #   end
  #
  #   # Chain tasks by passing Result objects
  #   extraction_result = ExtractDataTask.call(source_id: 123)
  #   processing_result = ProcessDataTask.call(extraction_result)
  #
  #   # Result object context is automatically extracted
  #   processing_result.context.extracted_data #=> data from first task
  #   processing_result.context.processed_data #=> data from second task
  #
  # @example Using callbacks
  #   class ProcessOrderTask < CMDx::Task
  #     before_validation :log_start
  #     after_execution :cleanup_resources
  #     on_success :send_confirmation
  #     on_failure :alert_support, if: :critical_order?
  #
  #     def call
  #       # Implementation
  #     end
  #
  #     private
  #
  #     def critical_order?
  #       context.order.value > 10_000
  #     end
  #   end
  #
  # == Task Chaining and Data Flow
  #
  # Tasks can be seamlessly chained by passing Result objects between them.
  # This enables powerful workflows where the output of one task becomes the
  # input for the next, maintaining data consistency and enabling complex
  # business logic composition.
  #
  # Benefits of Result object chaining:
  # - Automatic context extraction and data flow
  # - Preserves all context data including custom attributes
  # - Maintains execution chain relationships
  # - Enables conditional task execution based on previous results
  # - Simplifies error handling and rollback scenarios
  #
  # @see Result Result object for execution outcomes
  # @see Context Context object for parameter access
  # @see ParameterRegistry Parameter definition and validation
  # @see Workflow Workflow for executing multiple tasks
  # @since 1.0.0
  class Task

    __cmdx_attr_setting :task_settings,
                        default: -> { CMDx.configuration.to_h.slice(:logger, :task_halt, :workflow_halt).merge(tags: []) }
    __cmdx_attr_setting :cmd_middlewares,
                        default: -> { MiddlewareRegistry.new(CMDx.configuration.middlewares) }
    __cmdx_attr_setting :cmd_callbacks,
                        default: -> { CallbackRegistry.new(CMDx.configuration.callbacks) }
    __cmdx_attr_setting :cmd_parameters,
                        default: -> { ParameterRegistry.new }

    __cmdx_attr_delegator :cmd_middlewares, :cmd_callbacks, :cmd_parameters, :task_setting, :task_setting?,
                          to: :class
    __cmdx_attr_delegator :skip!, :fail!, :throw!,
                          to: :result

    ##
    # @!attribute [r] context
    #   @return [Context] parameter context for this task execution
    attr_reader :context

    ##
    # @!attribute [r] errors
    #   @return [Errors] collection of validation and execution errors
    attr_reader :errors

    ##
    # @!attribute [r] id
    #   @return [String] unique identifier for this task instance
    attr_reader :id

    ##
    # @!attribute [r] result
    #   @return [Result] execution result tracking state and status
    attr_reader :result

    ##
    # @!attribute [r] chain
    #   @return [Chain] execution chain containing this task and related executions
    attr_reader :chain

    # @return [Context] alias for context
    alias ctx context

    # @return [Result] alias for result
    alias res result

    ##
    # Initializes a new task instance with the given context parameters.
    #
    # The context can be provided as a Hash, Context object, or Result object.
    # When a Result object is passed, its context is automatically extracted,
    # enabling seamless task chaining and data flow between tasks.
    #
    # @param context [Hash, Context, Result] parameters and configuration for task execution
    # @example With hash parameters
    #   task = ProcessOrderTask.new(order_id: 123, notify_user: true)
    #
    # @example With Result object (task chaining)
    #   extraction_result = ExtractDataTask.call(source_id: 456)
    #   processing_task = ProcessDataTask.new(extraction_result)
    #   # Context from extraction_result is automatically extracted
    def initialize(context = {})
      context  = context.context if context.respond_to?(:context)

      @context = Context.build(context)
      @errors  = Errors.new
      @id      = CMDx::Correlator.generate
      @result  = Result.new(self)
      @chain   = Chain.build(@result)
    end

    class << self

      ##
      # Dynamically defines callback methods for each available callback type.
      # Each callback method accepts callables and options for conditional execution.
      #
      # @example Callback with method name
      #   before_validation :validate_permissions
      #
      # @example Callback with proc
      #   on_success -> { logger.info "Task completed successfully" }
      #
      # @example Callback with conditions
      #   on_failure :alert_support, if: :critical_error?
      #   after_execution :cleanup, unless: :skip_cleanup?
      #
      # @param callables [Array<Symbol, Proc, #call>] methods or callables to execute
      # @param options [Hash] conditions for callback execution
      # @option options [Symbol, Proc, #call] :if condition that must be truthy
      # @option options [Symbol, Proc, #call] :unless condition that must be falsy
      # @param block [Proc] block to execute as part of the callback
      # @return [Array] updated callbacks array
      CallbackRegistry::TYPES.each do |callback|
        define_method(callback) do |*callables, **options, &block|
          cmd_callbacks.register(callback, *callables, **options, &block)
        end
      end

      ##
      # Retrieves a task setting value, evaluating it if it's a callable.
      #
      # @param key [Symbol, String] setting key to retrieve
      # @return [Object] the setting value
      # @example
      #   task_setting(:timeout) #=> 30
      def task_setting(key)
        __cmdx_yield(task_settings[key])
      end

      ##
      # Checks if a task setting exists.
      #
      # @param key [Symbol, String] setting key to check
      # @return [Boolean] true if setting exists
      def task_setting?(key)
        task_settings.key?(key)
      end

      ##
      # Updates task settings with new options.
      #
      # @param options [Hash] settings to merge
      # @return [Hash] updated settings
      # @example
      #   task_settings!(timeout: 60, retries: 3)
      def task_settings!(**options)
        task_settings.merge!(options)
      end

      ##
      # Adds middleware to the task execution stack.
      #
      # Middleware can wrap task execution to provide cross-cutting concerns
      # like logging, authentication, caching, or error handling.
      #
      # @param middleware [Class, Object, Proc] middleware to add
      # @param args [Array] arguments for middleware instantiation
      # @param block [Proc] block for middleware instantiation
      # @return [MiddlewareRegistry] updated middleware registry
      # @example
      #   use LoggingMiddleware
      #   use AuthenticationMiddleware, "admin"
      #   use CachingMiddleware.new(ttl: 300)
      def use(middleware, ...)
        cmd_middlewares.use(middleware, ...)
      end

      ##
      # Defines optional parameters for the task.
      #
      # @param attributes [Array<Symbol>] parameter names
      # @param options [Hash] parameter options (type, default, validations, etc.)
      # @param block [Proc] block for nested parameter definitions
      # @return [ParameterRegistry] updated parameters collection
      # @example
      #   optional :timeout, type: :integer, default: 30
      #   optional :options, type: :hash do
      #     required :api_key, type: :string
      #   end
      def optional(*attributes, **options, &)
        parameters = Parameter.optional(*attributes, **options.merge(klass: self), &)
        cmd_parameters.concat(parameters)
      end

      ##
      # Defines required parameters for the task.
      #
      # @param attributes [Array<Symbol>] parameter names
      # @param options [Hash] parameter options (type, validations, etc.)
      # @param block [Proc] block for nested parameter definitions
      # @return [ParameterRegistry] updated parameters collection
      # @example
      #   required :user_id, type: :integer
      #   required :profile, type: :hash do
      #     required :name, type: :string
      #     optional :age, type: :integer
      #   end
      def required(*attributes, **options, &)
        parameters = Parameter.required(*attributes, **options.merge(klass: self), &)
        cmd_parameters.concat(parameters)
      end

      ##
      # Executes the task with the given parameters, returning a result object.
      # This method handles all exceptions and ensures the task completes properly.
      #
      # Parameters can be provided as a Hash, Context object, or Result object.
      # When a Result object is passed, its context is automatically extracted,
      # enabling seamless task chaining.
      #
      # @param args [Array] arguments passed to task initialization
      # @return [Result] execution result with state and status information
      # @example With hash parameters
      #   result = ProcessOrderTask.call(order_id: 123)
      #   result.success? #=> true or false
      #   result.context.order #=> processed order
      #
      # @example With Result object (task chaining)
      #   extraction_result = ExtractDataTask.call(source_id: 456)
      #   processing_result = ProcessDataTask.call(extraction_result)
      #   # Context from extraction_result is automatically used
      #   processing_result.context.source_id #=> 456
      def call(...)
        instance = new(...)
        instance.perform
        instance.result
      end

      ##
      # Executes the task with the given parameters, raising exceptions for failures.
      # This method is useful in background jobs where retries are handled via exceptions.
      #
      # Parameters can be provided as a Hash, Context object, or Result object.
      # When a Result object is passed, its context is automatically extracted,
      # enabling seamless task chaining with exception propagation.
      #
      # @param args [Array] arguments passed to task initialization
      # @return [Result] execution result if successful
      # @raise [Fault] if task fails and task_halt includes the failure status
      # @example With hash parameters
      #   begin
      #     result = ProcessOrderTask.call!(order_id: 123)
      #   rescue CMDx::Failed => e
      #     # Handle failure
      #   end
      #
      # @example With Result object (task chaining)
      #   begin
      #     extraction_result = ExtractDataTask.call!(source_id: 456)
      #     processing_result = ProcessDataTask.call!(extraction_result)
      #   rescue CMDx::Failed => e
      #     # Handle failure from either task
      #   end
      def call!(...)
        instance = new(...)
        instance.perform!
        instance.result
      end

    end

    ##
    # The main execution method that must be implemented by subclasses.
    # This method contains the core business logic of the task.
    #
    # @abstract Subclasses must implement this method
    # @return [void]
    # @raise [UndefinedCallError] if not implemented in subclass
    # @example
    #   def call
    #     context.user = User.find(user_id)
    #     fail!(reason: "User not found") unless context.user
    #
    #     context.user.activate!
    #     context.activation_date = Time.now
    #   end
    def call
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

    ##
    # Executes the task with full exception handling for the non-bang call method.
    # Captures all exceptions and converts them to appropriate result states.
    #
    # @return [void]
    def perform
      return execute_call if cmd_middlewares.registry.empty?

      cmd_middlewares.call(self) { |task| task.send(:execute_call) }
    end

    ##
    # Executes the task with exception propagation for the bang call method.
    # Allows exceptions to bubble up for external handling.
    #
    # @return [void]
    # @raise [Fault] if task fails and task_halt includes the failure status
    def perform!
      return execute_call! if cmd_middlewares.registry.empty?

      cmd_middlewares.call(self) { |task| task.send(:execute_call!) }
    end

    private

    ##
    # Returns the logger instance for this task.
    #
    # @return [Logger] configured logger instance
    # @api private
    def logger
      Logger.call(self)
    end

    ##
    # Executes before-call callbacks and validations.
    # Sets up the execution context and validates parameters.
    #
    # @return [void]
    # @api private
    def before_call
      cmd_callbacks.call(self, :before_execution)

      result.executing!
      cmd_callbacks.call(self, :on_executing)

      cmd_callbacks.call(self, :before_validation)
      ParameterValidator.call(self)
      cmd_callbacks.call(self, :after_validation)
    end

    ##
    # Executes after-call callbacks based on execution results.
    # Handles state and status transitions with appropriate callbacks.
    #
    # @return [void]
    # @api private
    def after_call
      cmd_callbacks.call(self, :"on_#{result.state}")
      cmd_callbacks.call(self, :on_executed) if result.executed?

      cmd_callbacks.call(self, :"on_#{result.status}")
      cmd_callbacks.call(self, :on_good) if result.good?
      cmd_callbacks.call(self, :on_bad) if result.bad?

      cmd_callbacks.call(self, :after_execution)
    end

    ##
    # Finalizes task execution by freezing the task and logging results.
    #
    # @return [void]
    # @api private
    def terminate_call
      Immutator.call(self)
      ResultLogger.call(result)
    end

    ##
    # Executes the task directly without middleware for the non-bang call method.
    #
    # @return [void]
    # @api private
    def execute_call
      result.runtime do
        before_call
        call
      rescue UndefinedCallError => e
        raise(e)
      rescue Fault => e
        throw!(e.result, original_exception: e) if Array(task_setting(:task_halt)).include?(e.result.status)
      rescue StandardError => e
        fail!(reason: "[#{e.class}] #{e.message}", original_exception: e)
      ensure
        result.executed!
        after_call
      end

      terminate_call
    end

    ##
    # Executes the task directly without middleware for the bang call method.
    #
    # @return [void]
    # @api private
    def execute_call!
      result.runtime do
        before_call
        call
      rescue UndefinedCallError => e
        Chain.clear
        raise(e)
      rescue Fault => e
        result.executed!

        if Array(task_setting(:task_halt)).include?(e.result.status)
          Chain.clear
          raise(e)
        end

        after_call # HACK: treat as NO-OP
      else
        result.executed!
        after_call # ELSE: treat as success
      end

      terminate_call
    end

  end
end
