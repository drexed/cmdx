# frozen_string_literal: true

module CMDx
  ##
  # Task is the base class for all command objects in CMDx, providing a framework
  # for encapsulating business logic with parameter validation, hooks, and result tracking.
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
  #       skip!("Order already processed") if context.order.processed?
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
  # @example Using hooks
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
  # @see Result Result object for execution outcomes
  # @see Context Context object for parameter access
  # @see Parameters Parameter definition and validation
  # @see Batch Batch for executing multiple tasks
  # @since 0.6.0
  class Task

    ##
    # Available hook types for task lifecycle events.
    # Hooks are executed in a specific order during task execution.
    #
    # @return [Array<Symbol>] frozen array of available hook names
    HOOKS = [
      :before_validation,
      :after_validation,
      :before_execution,
      :after_execution,
      :on_executed,
      :on_good,
      :on_bad,
      *Result::STATUSES.map { |s| :"on_#{s}" },
      *Result::STATES.map { |s| :"on_#{s}" }
    ].freeze

    __cmdx_attr_setting :task_settings, default: -> { CMDx.configuration.to_h.merge(tags: []) }
    __cmdx_attr_setting :cmd_parameters, default: -> { Parameters.new }
    __cmdx_attr_setting :cmd_hooks, default: {}

    __cmdx_attr_delegator :task_setting, :task_setting?, to: :class
    __cmdx_attr_delegator :skip!, :fail!, :throw!, to: :result

    ##
    # @!attribute [r] id
    #   @return [String] unique identifier for this task instance

    ##
    # @!attribute [r] errors
    #   @return [Errors] collection of validation and execution errors

    ##
    # @!attribute [r] context
    #   @return [Context] parameter context for this task execution

    ##
    # @!attribute [r] result
    #   @return [Result] execution result tracking state and status

    ##
    # @!attribute [r] run
    #   @return [Run] execution run containing this task and related executions
    attr_reader :id, :errors, :context, :result, :run

    ##
    # @!attribute [r] ctx
    #   @return [Context] alias for context
    alias ctx context

    ##
    # @!attribute [r] res
    #   @return [Result] alias for result
    alias res result

    private_class_method :new

    ##
    # Initializes a new task instance with the given context parameters.
    # Tasks cannot be instantiated directly; use the class-level call methods.
    #
    # @param context [Hash, Context] parameters and configuration for task execution
    # @api private
    def initialize(context = {})
      @id      = SecureRandom.uuid
      @errors  = Errors.new
      @context = Context.build(context)
      @run = @context.run || begin
        run = Run.new(@context.delete!(:run).to_h)
        @context.instance_variable_set(:@run, run)
      end
      @run.results << @result = Result.new(self)
    end

    class << self

      ##
      # Dynamically defines hook methods for each available hook type.
      # Each hook method accepts callables and options for conditional execution.
      #
      # @example Hook with method name
      #   before_validation :validate_permissions
      #
      # @example Hook with proc
      #   on_success -> { logger.info "Task completed successfully" }
      #
      # @example Hook with conditions
      #   on_failure :alert_support, if: :critical_error?
      #   after_execution :cleanup, unless: :skip_cleanup?
      #
      # @param callables [Array<Symbol, Proc, #call>] methods or callables to execute
      # @param options [Hash] conditions for hook execution
      # @option options [Symbol, Proc, #call] :if condition that must be truthy
      # @option options [Symbol, Proc, #call] :unless condition that must be falsy
      # @param block [Proc] block to execute as part of the hook
      # @return [Array] updated hooks array
      HOOKS.each do |hook|
        define_method(hook) do |*callables, **options, &block|
          callables << block if block_given?
          (cmd_hooks[hook] ||= []).push([callables, options]).uniq!
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
      # Defines optional parameters for the task.
      #
      # @param attributes [Array<Symbol>] parameter names
      # @param options [Hash] parameter options (type, default, validations, etc.)
      # @param block [Proc] block for nested parameter definitions
      # @return [Parameters] updated parameters collection
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
      # @return [Parameters] updated parameters collection
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
      # @param args [Array] arguments passed to task initialization
      # @return [Result] execution result with state and status information
      # @example
      #   result = ProcessOrderTask.call(order_id: 123)
      #   result.success? #=> true or false
      #   result.context.order #=> processed order
      def call(...)
        instance = send(:new, ...)
        instance.send(:execute_call)
        instance.result
      end

      ##
      # Executes the task with the given parameters, raising exceptions for failures.
      # This method is useful in background jobs where retries are handled via exceptions.
      #
      # @param args [Array] arguments passed to task initialization
      # @return [Result] execution result if successful
      # @raise [Fault] if task fails and task_halt includes the failure status
      # @example
      #   begin
      #     result = ProcessOrderTask.call!(order_id: 123)
      #   rescue CMDx::Failed => e
      #     # Handle failure
      #   end
      def call!(...)
        instance = send(:new, ...)
        instance.send(:execute_call!)
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
    #     fail!("User not found") unless context.user
    #
    #     context.user.activate!
    #     context.activation_date = Time.current
    #   end
    def call
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
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
    # Executes before-call hooks and validations.
    # Sets up the execution context and validates parameters.
    #
    # @return [void]
    # @api private
    def before_call
      TaskHook.call(self, :before_execution)

      result.executing!
      TaskHook.call(self, :on_executing)

      TaskHook.call(self, :before_validation)
      ParameterValidator.call(self)
      TaskHook.call(self, :after_validation)
    end

    ##
    # Executes after-call hooks based on execution results.
    # Handles state and status transitions with appropriate hooks.
    #
    # @return [void]
    # @api private
    def after_call
      TaskHook.call(self, :"on_#{result.state}")
      TaskHook.call(self, :on_executed) if result.executed?

      TaskHook.call(self, :"on_#{result.status}")
      TaskHook.call(self, :on_good) if result.good?
      TaskHook.call(self, :on_bad) if result.bad?

      TaskHook.call(self, :after_execution)
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
    # Executes the task with full exception handling for the non-bang call method.
    # Captures all exceptions and converts them to appropriate result states.
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
    # Executes the task with exception propagation for the bang call method.
    # Allows exceptions to bubble up for external handling.
    #
    # @return [void]
    # @raise [Fault] if task fails and task_halt includes the failure status
    # @api private
    def execute_call!
      result.runtime do
        before_call
        call
      rescue UndefinedCallError => e
        raise(e)
      rescue Fault => e
        result.executed!
        raise(e) if Array(task_setting(:task_halt)).include?(e.result.status)

        after_call # HACK: treat as NO-OP
      else
        result.executed!
        after_call # ELSE: treat as success
      end

      terminate_call
    end

  end
end
