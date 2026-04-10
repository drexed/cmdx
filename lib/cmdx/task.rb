# frozen_string_literal: true

module CMDx
  # Base class for all tasks. Subclass and implement +#work+.
  # Optionally override +#rollback+ for failure recovery.
  #
  # @example
  #   class CreateUser < CMDx::Task
  #     required :email, :string, presence: true
  #     optional :name, :string
  #     returns :user
  #
  #     def work
  #       ctx.user = User.create!(email:, name:)
  #     end
  #   end
  class Task

    # @return [Context]
    attr_reader :context
    alias ctx context

    # @return [Hash{Symbol => Object}]
    #
    # @rbs () -> Hash[Symbol, untyped]
    def attributes
      @_attributes || {}
    end

    # @return [String]
    #
    # @rbs () -> String
    def id
      @id ||= Identifier.generate
    end

    # @return [Logger]
    #
    # @rbs () -> Logger
    def logger
      @logger ||= CMDx.configuration.logger
    end

    # The main entry point. Subclasses MUST override this.
    #
    # @raise [UndefinedMethodError]
    #
    # @rbs () -> void
    def work
      raise UndefinedMethodError, "undefined method #{self.class.name}#work"
    end

    # Optional rollback hook. Called when execution fails.
    #
    # @rbs () -> void
    def rollback; end

    # --- Signal methods (throw-based control flow) ---

    # Annotates success with optional metadata. Halts by default.
    #
    # @param reason [String, nil]
    # @param halt [Boolean]
    # @param metadata [Hash]
    #
    # @rbs (?String? reason, ?halt: bool, **untyped metadata) -> void
    def success!(reason = nil, halt: true, **metadata)
      raise "cannot annotate after interruption" if @_signal

      @_success = { reason:, metadata: }
      throw(Outcome::HALT_TAG, { status: :success, reason:, metadata: }) if halt
    end

    # Signals a skip. Halts by default.
    #
    # @param reason [String, nil]
    # @param halt [Boolean]
    # @param strict [Boolean]
    # @param metadata [Hash]
    #
    # @rbs (?String? reason, ?halt: bool, ?strict: bool, **untyped metadata) -> void
    def skip!(reason = nil, halt: true, strict: true, **metadata)
      return if @_signal

      signal = { status: :skipped, reason:, strict:, metadata: }
      halt ? throw(Outcome::HALT_TAG, signal) : (@_signal ||= signal)
    end

    # Signals a failure. Halts by default.
    #
    # @param reason [String, nil]
    # @param halt [Boolean]
    # @param strict [Boolean]
    # @param metadata [Hash]
    #
    # @rbs (?String? reason, ?halt: bool, ?strict: bool, **untyped metadata) -> void
    def fail!(reason = nil, halt: true, strict: true, **metadata)
      signal = { status: :failed, reason:, strict:, metadata: }
      halt ? throw(Outcome::HALT_TAG, signal) : (@_signal ||= signal)
    end

    # Re-throws another task's failure into this execution.
    #
    # @param other_result [Result]
    # @param halt [Boolean]
    # @param metadata [Hash]
    #
    # @rbs (Result other_result, ?halt: bool, **untyped metadata) -> void
    def throw!(other_result, halt: true, **metadata)
      signal = {
        status: other_result.status.to_sym,
        reason: other_result.reason,
        cause: other_result.cause,
        strict: other_result.strict?,
        metadata: (other_result.metadata || {}).merge(metadata),
        thrown_from: other_result.task_id
      }
      halt ? throw(Outcome::HALT_TAG, signal) : (@_signal ||= signal)
    end

    # Whether this execution is a dry run.
    #
    # @return [Boolean]
    #
    # @rbs () -> bool
    def dry_run?
      !!context[:dry_run]
    end

    # --- Class-level DSL ---

    class << self

      # @param sub [Class]
      #
      # @rbs (Class sub) -> void
      def inherited(sub)
        super
        sub.remove_instance_variable(:@cmdx_definition) if sub.instance_variable_defined?(:@cmdx_definition)
      end

      # Executes the task and returns a frozen Result.
      #
      # @param args [Hash]
      # @return [Result]
      #
      # @rbs (**untyped args) ?{ (Result) -> void } -> Result
      def execute(**args, &)
        Runtime.call(self, args, raise_on_fault: false, &)
      end

      # Executes the task; raises FailFault or SkipFault on non-success.
      #
      # @param args [Hash]
      # @return [Result]
      # @raise [FailFault, SkipFault]
      #
      # @rbs (**untyped args) ?{ (Result) -> void } -> Result
      def execute!(**args, &)
        Runtime.call(self, args, raise_on_fault: true, &)
      end

      # Returns the compiled Definition for this class.
      #
      # @return [Definition]
      #
      # @rbs () -> Definition
      def definition
        Definition.fetch(self)
      end

      # --- Attribute DSL ---

      # Declares a required attribute.
      #
      # @param name [Symbol]
      # @param type [Symbol, nil]
      # @param options [Hash]
      #
      # @rbs (Symbol name, ?Symbol? type, **untyped options) ?{ () -> void } -> void
      def required(name, type = nil, **options, &)
        define_attribute(name, type, required: true, **options, &)
      end

      # Declares an optional attribute.
      #
      # @param name [Symbol]
      # @param type [Symbol, nil]
      # @param options [Hash]
      #
      # @rbs (Symbol name, ?Symbol? type, **untyped options) ?{ () -> void } -> void
      def optional(name, type = nil, **options, &)
        define_attribute(name, type, required: false, **options, &)
      end

      # Generic attribute declaration.
      #
      # @rbs (Symbol name, ?Symbol? type, **untyped options) ?{ () -> void } -> void
      def attribute(name, type = nil, ...)
        define_attribute(name, type, ...)
      end

      # Removes a declared attribute (for subclass overrides).
      #
      # @param name [Symbol]
      #
      # @rbs (Symbol name) -> void
      def remove_attribute(name)
        cmdx_attributes.reject! { |a| a.name == name.to_sym }
        invalidate_definition!
      end

      # @return [Hash]
      #
      # @rbs () -> Hash[Symbol, untyped]
      def attributes_schema
        definition.attributes.to_h { |a| [a.name, a.to_h] }
      end

      # --- Returns DSL ---

      # Declares an expected context key after successful execution.
      #
      # @param name [Symbol]
      # @param options [Hash]
      #
      # @rbs (Symbol name, **untyped options) -> void
      def returns(name, **options)
        cmdx_returns << { name: name.to_sym, options: }
        invalidate_definition!
      end

      # Removes a declared return.
      #
      # @param name [Symbol]
      #
      # @rbs (Symbol name) -> void
      def remove_returns(name)
        cmdx_returns.reject! { |r| r[:name] == name.to_sym }
        invalidate_definition!
      end

      # --- Callback DSL ---

      Definition::CALLBACK_PHASES.each do |phase|
        define_method(phase) do |*callables, **options, &block|
          entries = callables.map { |c| [c, options] }
          entries << [block, options] if block
          cmdx_callbacks[phase] ||= []
          cmdx_callbacks[phase].concat(entries)
          invalidate_definition!
        end
      end

      # --- Registration DSL ---

      # Registers middleware, coercions, or validators.
      #
      # @param type [Symbol] :middleware, :coercion, or :validator
      # @param args [Array] registration arguments
      #
      # @rbs (Symbol type, *untyped args, **untyped options) -> void
      def register(type, *args, **options)
        case type
        when :middleware
          cmdx_middleware << [args.first, options]
        when :coercion
          cmdx_coercions[args.first] = args[1]
        when :validator
          cmdx_validators[args.first] = args[1]
        else
          raise ArgumentError, "unknown registration type: #{type}"
        end
        invalidate_definition!
      end

      # Removes a middleware.
      #
      # @param type [Symbol]
      # @param klass [Class]
      #
      # @rbs (Symbol type, Class klass) -> void
      def deregister(type, klass)
        case type
        when :middleware
          cmdx_middleware.reject! { |(k, _)| k == klass }
        when :coercion
          cmdx_coercions.delete(klass)
        when :validator
          cmdx_validators.delete(klass)
        end
        invalidate_definition!
      end

      # --- Settings DSL ---

      # Configures per-task settings.
      #
      # @rbs (**untyped options) -> void
      def settings(**options)
        options.each do |key, value|
          ivar = :"@cmdx_#{key}"
          case key
          when :retries
            @cmdx_retry_policy = if value.is_a?(::Hash)
                                   RetryPolicy.new(value[:count] || 0, **value.except(:count))
                                 else
                                   RetryPolicy.new(value)
                                 end
          when :tags
            @cmdx_tags = Array(value)
          when :deprecate
            @cmdx_deprecate = value
          when :rollback_on
            @cmdx_rollback_on = Array(value).map(&:to_s)
          when :task_breakpoints
            @cmdx_task_breakpoints = Array(value).map(&:to_s)
          when :workflow_breakpoints
            @cmdx_workflow_breakpoints = Array(value).map(&:to_s)
          when :on_failure
            @cmdx_on_failure = value
          else
            instance_variable_set(ivar, value) if respond_to_setting?(key)
          end
        end
        invalidate_definition!
      end

      # @return [String]
      #
      # @rbs () -> String
      def task_type
        Utils::Format.type_name(self)
      end

      # @return [Boolean]
      #
      # @rbs () -> bool
      def cmdx_workflow?
        false
      end

      # --- Internal delta accessors ---

      # @rbs () -> Array[Attribute]
      def cmdx_attributes
        @cmdx_attributes ||= []
      end

      # @rbs () -> Array[Hash[Symbol, untyped]]
      def cmdx_returns
        @cmdx_returns ||= []
      end

      # @rbs () -> Hash[Symbol, Array[untyped]]
      def cmdx_callbacks
        @cmdx_callbacks ||= {}
      end

      # @rbs () -> Array[Array[untyped]]
      def cmdx_middleware
        @cmdx_middleware ||= []
      end

      # @rbs () -> Hash[Symbol, untyped]
      def cmdx_coercions
        @cmdx_coercions ||= {}
      end

      # @rbs () -> Hash[Symbol, untyped]
      def cmdx_validators
        @cmdx_validators ||= {}
      end

      # @rbs () -> Array[Hash[Symbol, untyped]]
      def cmdx_workflow_pipeline
        @cmdx_workflow_pipeline ||= []
      end

      private

      # @rbs (Symbol name, Symbol? type, **untyped options) ?{ () -> void } -> void
      def define_attribute(name, type = nil, **options, &block)
        opts = options.dup
        opts[:type] = type if type

        children = nil
        if block
          builder = AttributeBuilder.new
          builder.instance_eval(&block)
          children = builder.attributes
        end

        cmdx_attributes << Attribute.new(name, opts, children)
        invalidate_definition!
      end

      # @rbs () -> void
      def invalidate_definition!
        remove_instance_variable(:@cmdx_definition) if instance_variable_defined?(:@cmdx_definition)
      end

      # @rbs (Symbol key) -> bool
      def respond_to_setting?(key)
        %i[logger log_level log_formatter backtrace backtrace_cleaner
           exception_handler dump_context strong_context].include?(key)
      end

    end

    # DSL helper for building nested attribute children.
    class AttributeBuilder

      # @return [Array<Attribute>]
      attr_reader :attributes

      # @rbs () -> void
      def initialize
        @attributes = []
      end

      # @rbs (Symbol name, ?Symbol? type, **untyped options) -> void
      def required(name, type = nil, **options)
        @attributes << Attribute.new(name, { type:, required: true, **options })
      end

      # @rbs (Symbol name, ?Symbol? type, **untyped options) -> void
      def optional(name, type = nil, **options)
        @attributes << Attribute.new(name, { type:, required: false, **options })
      end

    end

  end
end
