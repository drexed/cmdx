# frozen_string_literal: true

module CMDx
  # Base class for all CMDx tasks. Inherit and define a `work` method.
  #
  # @example
  #   class Greet < CMDx::Task
  #     required :name, type: :string, presence: true
  #
  #     def work
  #       context.greeting = "Hello, #{name}!"
  #     end
  #   end
  class Task

    include Callbacks
    include MiddlewareStack
    include Returns

    attr_reader :context, :result, :errors, :id

    alias ctx context
    alias res result

    class << self

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@attribute_set, attribute_set.dup)
        subclass.instance_variable_set(:@task_settings, nil)
        subclass.instance_variable_set(:@coercion_registry, coercion_registry.dup)
        subclass.instance_variable_set(:@validator_registry, validator_registry.dup)
      end

      # -- Execution --

      # Execute the task, always returning a Result.
      #
      # @param args [Hash]
      # @yield [CMDx::Result]
      # @return [CMDx::Result]
      def execute(args = {}, &block)
        task = new(args)
        task.execute
        result = task.result
        block&.call(result)
        result
      end

      # Execute the task, raising Fault on failure/skip.
      #
      # @param args [Hash]
      # @yield [CMDx::Result]
      # @return [CMDx::Result]
      # @raise [CMDx::FailFault, CMDx::SkipFault]
      def execute!(args = {}, &block)
        task = new(args)
        task.execute!
        result = task.result
        block&.call(result)
        result
      end

      # -- Attribute DSL --

      # @return [CMDx::AttributeSet]
      def attribute_set
        @attribute_set ||= AttributeSet.new
      end

      # rubocop:disable Style/ArgumentsForwarding, Naming/BlockForwarding
      def attribute(*names, **options, &block)
        attribute_set.define(*names, **options, &block)
        attribute_set.define_accessors(self)
      end
      alias attributes attribute

      def optional(*names, **options, &block)
        attribute(*names, **options, &block)
      end

      def required(*names, **options, &block)
        attribute(*names, required: true, **options, &block)
      end
      # rubocop:enable Style/ArgumentsForwarding, Naming/BlockForwarding

      def remove_attribute(*names)
        names.each { |n| attribute_set.remove(n) }
      end
      alias remove_attributes remove_attribute

      # @return [Hash]
      def attributes_schema
        attribute_set.schema
      end

      # -- Settings --

      # @return [CMDx::Settings]
      def task_settings
        @task_settings ||= begin
          parent = superclass.respond_to?(:task_settings) ? superclass.task_settings : nil
          Settings.new(parent: parent)
        end
      end

      def settings(**options)
        task_settings.merge!(options)
      end

      # -- Per-task registries --

      def coercion_registry
        @coercion_registry ||= {}
      end

      def validator_registry
        @validator_registry ||= {}
      end

      # Unified register API.
      #
      # @param type [Symbol] :middleware, :coercion, :validator, :callback
      def register(type, *args, **options)
        case type
        when :middleware
          register_middleware(args.first, **options)
        when :coercion
          name, callable = args
          coercion_registry[name.to_sym] = Callable.wrap(callable)
        when :validator
          name, callable = args
          validator_registry[name.to_sym] = Callable.wrap(callable)
        when :callback
          cb_type, *callables = args
          callables.each do |cb|
            callback_registry[cb_type.to_sym] << { callable: Callable.wrap(cb), conditions: options }
          end
        end
      end

      # Unified deregister API.
      def deregister(type, *args)
        case type
        when :middleware
          deregister_middleware(args.first)
        when :coercion
          coercion_registry.delete(args.first.to_sym)
        when :validator
          validator_registry.delete(args.first.to_sym)
        when :callback
          cb_type, callable = args
          deregister_callback(cb_type, callable)
        end
      end

    end

    def initialize(args = {})
      @id = Chain::UUID_V7 ? SecureRandom.uuid_v7 : SecureRandom.uuid
      @context = Context.build(args)
      @result = Result.new(task: self, context: @context)
      @errors = ErrorSet.new
      @__attributes__ = {}
      @executed = false
    end

    # Non-bang execution.
    def execute
      raise_if_executed!
      @executed = true

      begin
        check_deprecation!
        check_work_defined!
        setup_chain!

        run_middleware_chain { execute_core }
      rescue StandardError => e
        handle_exception(e)
      ensure
        finalize!
      end
    end

    # Bang execution -- raises Fault on failure/skip.
    def execute!
      result.mark_strict!
      execute

      breakpoints = Array(self.class.task_settings.task_breakpoints)

      if breakpoints.include?(result.status)
        raise result.cause if result.cause.is_a?(Fault)

        fault_class = result.skipped? ? SkipFault : FailFault
        raise fault_class.new(result.reason, result: result)
      end

      result
    end

    # Override this method with your business logic.
    def work
      raise UndefinedMethodError, Messages.resolve("task.undefined_work", task: self.class.name)
    end

    # Override for undo logic.
    def rollback; end

    # @return [Boolean]
    def dry_run?
      !!context[:dry_run]
    end

    # @return [Logger]
    def logger
      self.class.task_settings.logger || CMDx.configuration.logger
    end

    # -- Halt methods --

    def skip!(reason = nil, **metadata)
      result.skip!(reason, **metadata)
    end

    def fail!(reason = nil, **metadata)
      result.fail!(reason, **metadata)
    end

    def success!(reason = nil, **metadata)
      result.succeed!(reason, **metadata)
    end

    def throw!(other_result, **metadata)
      result.throw!(other_result, **metadata)
    end

    private

    def execute_core
      result.transition_to_executing!

      run_before_callbacks(:before_validation)
      validate_attributes!
      return result unless result.success?

      run_execution_with_retries
      result
    end

    def run_execution_with_retries
      max_retries = self.class.task_settings.retries
      retry_on = self.class.task_settings.retry_on
      retry_jitter = self.class.task_settings.retry_jitter

      begin
        run_before_callbacks(:before_execution)
        work if result.success?
        validate_returns! if result.success?
      rescue *retry_on => e
        raise e unless result.retries < max_retries

        result.increment_retries!
        errors.clear
        apply_jitter(retry_jitter, result.retries)
        retry
      end

      maybe_rollback!
      run_after_callbacks
    end

    def validate_attributes!
      return if self.class.attribute_set.empty?

      @__attributes__ = self.class.attribute_set.process(
        self,
        task_coercions: self.class.coercion_registry.empty? ? nil : self.class.coercion_registry,
        task_validators: self.class.validator_registry.empty? ? nil : self.class.validator_registry
      )

      return if errors.empty?

      result.fail!(Messages.resolve("halt.invalid"),
                   errors: { full_message: errors.to_s, messages: errors.to_h })
    end

    def maybe_rollback!
      rollback_statuses = Array(self.class.task_settings.rollback_on)
      return unless rollback_statuses.include?(result.status)

      rollback
      result.mark_rolled_back!
    end

    def apply_jitter(jitter, attempt)
      delay = case jitter
              when Numeric then jitter * attempt
              when Symbol  then send(jitter, attempt)
              when Proc    then jitter.call(attempt)
              else
                jitter.respond_to?(:call) ? Callable.resolve(jitter, self, self, attempt) : 0
              end
      sleep(delay) if delay.is_a?(Numeric) && delay.positive?
    end

    def handle_exception(exception)
      return if result.interrupted?

      settings = self.class.task_settings
      result.fail_from_exception!(exception,
                                  backtrace_opt: settings.backtrace,
                                  backtrace_cleaner: settings.backtrace_cleaner)

      handler = settings.exception_handler
      Callable.resolve(handler, self, self, exception) if handler
    end

    def finalize!
      result.transition_to_complete! if result.executing?

      chain = Chain.current
      if chain
        chain.exit
        if chain.outermost?
          freeze_all! if self.class.task_settings.freeze_results
          Chain.clear
        end
      end

      log_result!
    end

    def freeze_all!
      chain = result.chain
      return unless chain

      chain.results.each do |r|
        r.freeze
        r.context.freeze
      end
      chain.freeze
    end

    def setup_chain!
      chain = Chain.current || Chain.new.tap { |c| Chain.current = c }
      chain.enter
      chain.add(result)
    end

    def check_deprecation!
      dep = self.class.task_settings.deprecate
      return unless dep

      mode = Callable.resolve(dep, self)
      mode = :log if mode == true

      case mode.to_s
      when "raise"
        raise DeprecationError, Messages.resolve("deprecation.prohibited", task: self.class.name)
      when "log"
        logger.warn(Messages.resolve("deprecation.warning", task: self.class.name))
      when "warn"
        Warning.warn("[#{self.class.name}] #{Messages.resolve('deprecation.warning', task: self.class.name)}\n")
      end
    end

    def check_work_defined!
      # Subclasses that include Workflow define work automatically
    end

    def raise_if_executed!
      raise "Task has already been executed" if @executed
    end

    def log_result!
      LogEntry.log(result, self.class.task_settings)
    rescue StandardError
      # Never let logging failures break task execution
    end

  end
end
