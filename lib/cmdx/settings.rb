# frozen_string_literal: true

module CMDx
  # Value object encapsulating all per-task configuration. Registries are
  # deep-duped on inheritance; scalar settings delegate to a parent Settings
  # or to the global Configuration rather than eagerly copying values.
  class Settings

    class << self

      private

      # Defines a reader that delegates to the parent Settings chain,
      # falling through to Configuration when no parent exists.
      #
      # @param names [Array<Symbol>] Setting names to define
      #
      # @rbs (*Symbol names) -> void
      def delegate_to_configuration(*names)
        names.each do |name|
          ivar = :"@#{name}"

          attr_writer(name)

          define_method(name) do
            return instance_variable_get(ivar) if instance_variable_defined?(ivar)

            value = @parent ? @parent.public_send(name) : CMDx.configuration.public_send(name)
            instance_variable_set(ivar, value)

            value
          end
        end
      end

      # Defines a reader that delegates to the parent Settings only.
      # Returns nil when the chain is exhausted.
      #
      # @param names [Array<Symbol>] Setting names to define
      # @param with_fallback [Boolean] Whether to fall back to Configuration
      #
      # @rbs (*Symbol names, with_fallback: bool) -> void
      def delegate_to_parent(*names, with_fallback: false)
        names.each do |name|
          ivar = :"@#{name}"

          attr_writer(name)

          define_method(name) do
            return instance_variable_get(ivar) if instance_variable_defined?(ivar)

            value = @parent&.public_send(name)
            value ||= CMDx.configuration.public_send(name) if with_fallback
            instance_variable_set(ivar, value)

            value
          end
        end
      end

    end

    # Returns the attribute registry for task parameters.
    #
    # @return [AttributeRegistry] The attribute registry
    #
    # @rbs @attributes: AttributeRegistry
    attr_accessor :attributes

    # Returns the callback registry for task lifecycle hooks.
    #
    # @return [CallbackRegistry] The callback registry
    #
    # @rbs @callbacks: CallbackRegistry
    attr_accessor :callbacks

    # Returns the coercion registry for type conversions.
    #
    # @return [CoercionRegistry] The coercion registry
    #
    # @rbs @coercions: CoercionRegistry
    attr_accessor :coercions

    # Returns the middleware registry for task execution.
    #
    # @return [MiddlewareRegistry] The middleware registry
    #
    # @rbs @middlewares: MiddlewareRegistry
    attr_accessor :middlewares

    # Returns the validator registry for attribute validation.
    #
    # @return [ValidatorRegistry] The validator registry
    #
    # @rbs @validators: ValidatorRegistry
    attr_accessor :validators

    # Returns the expected return keys after execution.
    #
    # @return [Array<Symbol>] Expected return keys after execution
    #
    # @rbs @returns: Array[Symbol]
    attr_accessor :returns

    # Returns the tags for task categorization.
    #
    # @return [Array<Symbol>] Tags for categorization
    #
    # @rbs @tags: Array[Symbol]
    attr_accessor :tags

    # @!attribute [rw] backtrace
    #   @return [Boolean] true if backtraces should be logged
    delegate_to_configuration :backtrace

    # @!attribute [rw] rollback_on
    #   @return [Array<String>] Statuses that trigger rollback
    delegate_to_configuration :rollback_on

    # @!attribute [rw] task_breakpoints
    #   @return [Array<String>] Default task breakpoint statuses
    delegate_to_configuration :task_breakpoints

    # @!attribute [rw] workflow_breakpoints
    #   @return [Array<String>] Default workflow breakpoint statuses
    delegate_to_configuration :workflow_breakpoints

    # @!attribute [rw] backtrace_cleaner
    #   @return [Proc, nil] The backtrace cleaner proc
    delegate_to_parent :backtrace_cleaner, with_fallback: true

    # @!attribute [rw] breakpoints
    #   @return [Array<String>, nil] Per-task breakpoints override
    delegate_to_parent :breakpoints

    # @!attribute [rw] deprecate
    #   @return [Symbol, Proc, Boolean, nil] Deprecation behavior
    delegate_to_parent :deprecate

    # @!attribute [rw] exception_handler
    #   @return [Proc, nil] The exception handler proc
    delegate_to_parent :exception_handler, with_fallback: true

    # @!attribute [rw] logger
    #   @return [Logger] The logger instance
    delegate_to_parent :logger, with_fallback: true

    # @!attribute [rw] log_formatter
    #   @return [Proc, nil] Per-task log formatter override
    delegate_to_parent :log_formatter

    # @!attribute [rw] log_level
    #   @return [Integer, nil] Per-task log level override
    delegate_to_parent :log_level

    # @!attribute [rw] retries
    #   @return [Integer, nil] Number of retries on failure
    delegate_to_parent :retries

    # @!attribute [rw] retry_jitter
    #   @return [Numeric, Symbol, Proc, nil] Jitter between retries
    delegate_to_parent :retry_jitter

    # @!attribute [rw] retry_on
    #   @return [Array<Class>, Class, nil] Exception classes to retry on
    delegate_to_parent :retry_on

    # Creates a new Settings instance, inheriting registries from a parent
    # Settings or the global Configuration. Scalar settings are resolved
    # lazily via delegation rather than eagerly copied.
    #
    # @param parent [Settings, nil] Parent settings to inherit from
    # @param overrides [Hash] Field values to override after inheritance
    #
    # @example
    #   Settings.new(parent: ParentTask.settings, deprecate: true)
    #
    # @rbs (?parent: Settings?, **untyped overrides) -> void
    def initialize(parent: nil, **overrides)
      @parent = parent

      init_registries
      init_collections

      overrides.each { |key, value| public_send(:"#{key}=", value) }
    end

    private

    # Dups registries from the parent Settings or global Configuration
    # so each task class gets its own mutable copy.
    #
    # @rbs () -> void
    def init_registries
      if @parent
        @middlewares = @parent.middlewares.dup
        @callbacks = @parent.callbacks.dup
        @coercions = @parent.coercions.dup
        @validators = @parent.validators.dup
        @attributes = @parent.attributes.dup
      else
        config = CMDx.configuration

        @middlewares = config.middlewares.dup
        @callbacks = config.callbacks.dup
        @coercions = config.coercions.dup
        @validators = config.validators.dup
        @attributes = AttributeRegistry.new
      end
    end

    # Initializes array-valued settings that need their own copy
    # to avoid cross-class mutation.
    #
    # @rbs () -> void
    def init_collections
      @returns = @parent&.returns&.dup || EMPTY_ARRAY
      @tags = @parent&.tags&.dup || EMPTY_ARRAY
    end

  end
end
