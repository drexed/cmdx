# frozen_string_literal: true

module CMDx
  # Base class for all units of work. Subclasses override `#work` and
  # declare their contract via `required`, `optional`, `output`, `callbacks`,
  # `retry_on`, `deprecation`, and `settings`. Invoked via {.execute} (safe)
  # or {.execute!} (strict, raises on failure).
  #
  # Inheritance: every registry accessor (middlewares, callbacks, coercions,
  # validators, executors, mergers, telemetry, inputs, outputs) lazily clones from the
  # superclass's registry (or the global configuration at the top of the
  # hierarchy), so subclasses extend rather than replace.
  #
  # @see Runtime
  # @see Workflow
  class Task

    class << self

      # Declares exceptions to retry on. Builds on the superclass's `Retry`.
      # Passing no exceptions returns the current (possibly inherited) Retry.
      #
      # @param exceptions [Array<Class>]
      # @param options [Hash{Symbol => Object}] see {Retry#initialize}
      # @option options [Integer] :limit (see {Retry#initialize})
      # @option options [Float] :delay (see {Retry#initialize})
      # @option options [Float] :max_delay (see {Retry#initialize})
      # @option options [Symbol, Proc, #call] :jitter (see {Retry#initialize})
      # @option options [Symbol, Proc, #call] :if gate `(task, error, attempt)` for retries
      # @option options [Symbol, Proc, #call] :unless gate `(task, error, attempt)` for retries
      # @yield [attempt, delay] optional custom jitter block
      # @return [Retry]
      def retry_on(*exceptions, **options, &)
        @retry_on ||=
          if superclass.respond_to?(:retry_on)
            superclass.retry_on.build(exceptions, options, &)
          else
            Retry.new(exceptions, options, &)
          end

        return @retry_on if exceptions.empty?

        @retry_on = @retry_on.build(exceptions, options, &)
      end

      # Reads or extends this class's {Settings}. Inherits from the superclass.
      #
      # @param options [Hash{Symbol => Object}] merged onto the current settings
      # @option options [Logger] :logger (see {Settings#initialize})
      # @option options [#call] :log_formatter (see {Settings#initialize})
      # @option options [Integer] :log_level (see {Settings#initialize})
      # @option options [#call] :backtrace_cleaner (see {Settings#initialize})
      # @option options [Array<Symbol>] :log_exclusions (see {Settings#initialize})
      # @option options [Array<Symbol, String>] :tags (see {Settings#initialize})
      # @option options [Boolean] :strict_context (see {Settings#initialize})
      # @return [Settings]
      def settings(options = EMPTY_HASH)
        @settings ||=
          if superclass.respond_to?(:settings)
            superclass.settings.build(options)
          else
            Settings.new(options)
          end

        return @settings if options.empty?

        @settings = @settings.build(options)
      end

      # @return [Middlewares] cloned from superclass/configuration on first call
      def middlewares
        @middlewares ||=
          if superclass.respond_to?(:middlewares)
            superclass.middlewares.dup
          else
            CMDx.configuration.middlewares.dup
          end
      end

      # @return [Callbacks] cloned from superclass/configuration on first call
      def callbacks
        @callbacks ||=
          if superclass.respond_to?(:callbacks)
            superclass.callbacks.dup
          else
            CMDx.configuration.callbacks.dup
          end
      end

      Callbacks::EVENTS.each do |event|
        define_method(event) do |callable = nil, **options, &block|
          register(:callback, event, callable, **options, &block)
        end
      end

      # @return [Telemetry] cloned from superclass/configuration on first call
      def telemetry
        @telemetry ||=
          if superclass.respond_to?(:telemetry)
            superclass.telemetry.dup
          else
            CMDx.configuration.telemetry.dup
          end
      end

      # @return [Coercions] cloned from superclass/configuration on first call
      def coercions
        @coercions ||=
          if superclass.respond_to?(:coercions)
            superclass.coercions.dup
          else
            CMDx.configuration.coercions.dup
          end
      end

      # @return [Validators] cloned from superclass/configuration on first call
      def validators
        @validators ||=
          if superclass.respond_to?(:validators)
            superclass.validators.dup
          else
            CMDx.configuration.validators.dup
          end
      end

      # @return [Executors] cloned from superclass/configuration on first call
      def executors
        @executors ||=
          if superclass.respond_to?(:executors)
            superclass.executors.dup
          else
            CMDx.configuration.executors.dup
          end
      end

      # @return [Mergers] cloned from superclass/configuration on first call
      def mergers
        @mergers ||=
          if superclass.respond_to?(:mergers)
            superclass.mergers.dup
          else
            CMDx.configuration.mergers.dup
          end
      end

      # @return [Retriers] cloned from superclass/configuration on first call
      def retriers
        @retriers ||=
          if superclass.respond_to?(:retriers)
            superclass.retriers.dup
          else
            CMDx.configuration.retriers.dup
          end
      end

      # @return [Deprecators] cloned from superclass/configuration on first call
      def deprecators
        @deprecators ||=
          if superclass.respond_to?(:deprecators)
            superclass.deprecators.dup
          else
            CMDx.configuration.deprecators.dup
          end
      end

      # Dispatches to the appropriate registry's `register` method.
      #
      # @param type [:middleware, :callback, :coercion, :validator, :executor, :merger, :retrier, :deprecator, :input, :output]
      # @return [Object] the registry's self
      # @raise [ArgumentError] when `type` is unknown
      def register(type, ...)
        case type
        when :middleware
          middlewares.register(...)
        when :callback
          callbacks.register(...)
        when :coercion
          coercions.register(...)
        when :validator
          validators.register(...)
        when :executor
          executors.register(...)
        when :merger
          mergers.register(...)
        when :retrier
          retriers.register(...)
        when :deprecator
          deprecators.register(...)
        when :input
          inputs.register(self, ...)
        when :output
          outputs.register(...)
        else raise ArgumentError, "unknown registry type: #{type.inspect}"
        end
      end

      # Dispatches to the appropriate registry's `deregister` method.
      #
      # @param type [:middleware, :callback, :coercion, :validator, :executor, :merger, :retrier, :deprecator, :input, :output]
      # @return [Object] the registry's self
      # @raise [ArgumentError] when `type` is unknown
      def deregister(type, ...)
        case type
        when :middleware
          middlewares.deregister(...)
        when :callback
          callbacks.deregister(...)
        when :coercion
          coercions.deregister(...)
        when :validator
          validators.deregister(...)
        when :executor
          executors.deregister(...)
        when :merger
          mergers.deregister(...)
        when :retrier
          retriers.deregister(...)
        when :deprecator
          deprecators.deregister(...)
        when :input
          inputs.deregister(self, ...)
        when :output
          outputs.deregister(...)
        else raise ArgumentError, "unknown registry type: #{type.inspect}"
        end
      end

      # Reads, sets, or inherits the task class's {Deprecation}. With a
      # `value` or block, replaces any current deprecation. Otherwise returns
      # the locally defined one, or the superclass's.
      #
      # @param value [:log, :warn, :error, Symbol, Proc, #call, nil]
      # @param block [#call, nil] optional block used as the deprecation callable
      # @param options [Hash{Symbol => Object}] `:if`/`:unless` conditions (see {Deprecation#initialize})
      # @option options [Symbol, Proc, #call] :if (see {Deprecation#initialize})
      # @option options [Symbol, Proc, #call] :unless (see {Deprecation#initialize})
      # @return [Deprecation, nil]
      # @yield optional block used as the deprecation callable
      def deprecation(value = nil, **options, &block)
        if value || block
          @deprecation = Deprecation.new(value || block, options)
        elsif defined?(@deprecation)
          @deprecation
        elsif superclass.respond_to?(:deprecation)
          superclass.deprecation
        end
      end

      # Reads, or declares more, inputs. With no names, returns the registry;
      # with names, registers them and defines accessors.
      #
      # @param names [Array<Symbol>]
      # @param options [Hash{Symbol => Object}] see {Input#initialize}
      # @option options [String] :description (also accepts `:desc`)
      # @option options [Symbol] :as overrides the accessor name
      # @option options [Boolean, String] :prefix prefix for the accessor name
      # @option options [Boolean, String] :suffix suffix for the accessor name
      # @option options [Symbol, Proc, #call] :source (`:context`) where to fetch from
      # @option options [Object, Symbol, Proc, #call] :default
      # @option options [Symbol, Proc, #call] :transform mutator applied after coercion
      # @option options [Symbol, Proc, #call] :if
      # @option options [Symbol, Proc, #call] :unless
      # @option options [Boolean] :required
      # @option options [Object] :coerce (see {Coercions#extract})
      # @option options [Object] :validate (see {Validators#extract})
      # @yield nested-input DSL block (see {Inputs::ChildBuilder})
      # @return [Inputs]
      def inputs(*names, **options, &)
        @inputs ||=
          if superclass.respond_to?(:inputs)
            superclass.inputs.dup
          else
            Inputs.new
          end

        return @inputs if names.empty?

        @inputs.register(self, *names, **options, &)
      end
      alias input inputs

      # Declares optional inputs (shorthand for `inputs ..., required: false`).
      #
      # @param names [Array<Symbol>]
      # @param options [Hash{Symbol => Object}] see {Input#initialize}
      # @option options [String] :description (also accepts `:desc`)
      # @option options [Symbol] :as overrides the accessor name
      # @option options [Boolean, String] :prefix prefix for the accessor name
      # @option options [Boolean, String] :suffix suffix for the accessor name
      # @option options [Symbol, Proc, #call] :source (`:context`) where to fetch from
      # @option options [Object, Symbol, Proc, #call] :default
      # @option options [Symbol, Proc, #call] :transform mutator applied after coercion
      # @option options [Symbol, Proc, #call] :if
      # @option options [Symbol, Proc, #call] :unless
      # @option options [Object] :coerce (see {Coercions#extract})
      # @option options [Object] :validate (see {Validators#extract})
      # @yield nested-input DSL block (see {Inputs::ChildBuilder})
      def optional(*names, **options, &)
        register(:input, *names, required: false, **options, &)
      end

      # Declares required inputs (shorthand for `inputs ..., required: true`).
      #
      # @param names [Array<Symbol>]
      # @param options [Hash{Symbol => Object}] see {Input#initialize}
      # @option options [String] :description (also accepts `:desc`)
      # @option options [Symbol] :as overrides the accessor name
      # @option options [Boolean, String] :prefix prefix for the accessor name
      # @option options [Boolean, String] :suffix suffix for the accessor name
      # @option options [Symbol, Proc, #call] :source (`:context`) where to fetch from
      # @option options [Object, Symbol, Proc, #call] :default
      # @option options [Symbol, Proc, #call] :transform mutator applied after coercion
      # @option options [Symbol, Proc, #call] :if
      # @option options [Symbol, Proc, #call] :unless
      # @option options [Object] :coerce (see {Coercions#extract})
      # @option options [Object] :validate (see {Validators#extract})
      # @yield nested-input DSL block (see {Inputs::ChildBuilder})
      def required(*names, **options, &)
        register(:input, *names, required: true, **options, &)
      end

      # @return [Hash{Symbol => Hash}] serialized input definitions
      def inputs_schema
        inputs.registry.transform_values(&:to_h)
      end

      # Reads, or declares more, outputs. With no keys, returns the registry.
      #
      # @param keys [Array<Symbol>]
      # @param options [Hash{Symbol => Object}] see {Output#initialize}
      # @option options [String] :description (also accepts `:desc`)
      # @option options [Symbol, Proc, #call] :if
      # @option options [Symbol, Proc, #call] :unless
      # @option options [Object, Symbol, Proc, #call] :default
      # @return [Outputs]
      def outputs(*keys, **options)
        @outputs ||=
          if superclass.respond_to?(:outputs)
            superclass.outputs.dup
          else
            Outputs.new
          end

        return @outputs if keys.empty?

        @outputs.register(*keys, **options)
      end
      alias output outputs

      # @return [Hash{Symbol => Hash}] serialized output definitions
      def outputs_schema
        outputs.registry.transform_values(&:to_h)
      end

      # @return [String] `"Workflow"` when the class includes {Workflow}, else `"Task"`
      def type
        @type ||= include?(Workflow) ? "Workflow" : "Task"
      end

      # Executes the task. Never raises on failure; inspect the returned
      # {Result} instead.
      #
      # @param context [Hash, Context, #context, #to_h]
      # @yieldparam result [Result]
      # @return [Result, Object] the yielded block's value when a block is given
      def execute(context = EMPTY_HASH, &)
        new(context).execute(strict: false, &)
      end
      alias call execute

      # Strict execution. Raises {Fault} (or the underlying exception) on
      # failure; otherwise identical to {.execute}.
      #
      # @param context [Hash, Context, #context, #to_h]
      # @yieldparam result [Result]
      # @return [Result, Object]
      # @raise [Fault, StandardError] on task failure
      def execute!(context = EMPTY_HASH, &)
        new(context).execute(strict: true, &)
      end
      alias call! execute!

      private

      # @param input [Input] defines `##{input.accessor_name}` when not already taken
      # @return [void]
      # @raise [DefinitionError] when the accessor name collides
      def define_input_reader(input)
        accessor = input.accessor_name

        if method_defined?(accessor) || private_method_defined?(accessor)
          raise DefinitionError,
            "cannot define input #{accessor.inspect}: ##{accessor} is already defined on #{self}"
        end

        define_method(accessor) { instance_variable_get(input.ivar_name) }
        input.children.each { |child| define_input_reader(child) }
      end

      # @param input [Input] removes `##{input.accessor_name}` if defined on this class
      # @return [void]
      def undefine_input_reader(input)
        accessor = input.accessor_name
        undef_method(accessor) if method_defined?(accessor)
        input.children.each { |child| undefine_input_reader(child) }
      end

    end

    attr_reader :tid, :context, :errors, :metadata
    alias ctx context

    # @param context [Hash, Context, #context, #to_h]
    # @note The built {Context} inherits `strict` mode from
    #   {Settings#strict_context} (falling back to
    #   {Configuration#strict_context}), so dynamic reads for unknown keys
    #   raise `NoMethodError` instead of returning `nil`.
    def initialize(context = EMPTY_HASH)
      @metadata = {}
      @tid      = SecureRandom.uuid_v7
      @errors   = Errors.new
      @context  = Context.build(context).tap do |c|
        c.strict = self.class.settings.strict_context
      end
    end

    # Executes this task instance through {Runtime}.
    #
    # @param strict [Boolean] when `true`, re-raises {Fault}/exceptions on failure;
    #   when `false`, swallows them and returns the {Result}
    # @yieldparam result [Result]
    # @return [Result, Object] the yielded block's value when a block is given,
    #   otherwise the {Result}
    # @raise [Fault, StandardError] only when `strict: true` and the task fails
    def execute(strict: false)
      result = Runtime.execute(self, strict:)
      block_given? ? yield(result) : result
    end
    alias call execute

    # @return [Logger] a logger tailored to this task's settings
    def logger
      @logger ||= LoggerProxy.logger(self)
    end

    # The task's core logic. Subclasses must override.
    #
    # @abstract
    # @return [void]
    # @raise [ImplementationError] when the subclass doesn't override
    def work
      raise ImplementationError, "undefined method #{self.class}#work"
    end

    private

    # Signals a successful halt.
    #
    # @param reason [String, nil]
    # @param sigdata [Hash{Symbol => Object}] arbitrary metadata merged into {#metadata} before throwing
    # @option sigdata [Object] arbitrary entries merged via `metadata.merge!`
    # @return [void] throws `Signal::TAG`; never returns
    # @raise [FrozenError] when the task has already been frozen (post-execution)
    # @note Must be called from inside `work` (inside Runtime's `catch(:cmdx_signal)`).
    def success!(reason = nil, **sigdata)
      raise FrozenError, "cannot throw signals" if frozen?

      metadata.merge!(sigdata) unless sigdata.empty?
      throw(Signal::TAG, Signal.success(reason, metadata:))
    end

    # Signals a skip (interrupted + skipped).
    #
    # @param reason [String, nil]
    # @param sigdata [Hash{Symbol => Object}] arbitrary metadata merged into {#metadata} before throwing
    # @option sigdata [Object] arbitrary entries merged via `metadata.merge!`
    # @return [void] throws `Signal::TAG`; never returns
    # @raise [FrozenError]
    def skip!(reason = nil, **sigdata)
      raise FrozenError, "cannot throw signals" if frozen?

      metadata.merge!(sigdata) unless sigdata.empty?
      throw(Signal::TAG, Signal.skipped(reason, metadata:))
    end

    # Signals a failure. Captures current call frames as the signal
    # backtrace for Fault propagation.
    #
    # @param reason [String, nil]
    # @param sigdata [Hash{Symbol => Object}] arbitrary metadata merged into {#metadata} before throwing
    # @option sigdata [Object] arbitrary entries merged via `metadata.merge!`
    # @return [void] throws `Signal::TAG`; never returns
    # @raise [FrozenError]
    def fail!(reason = nil, **sigdata)
      raise FrozenError, "cannot throw signals" if frozen?

      metadata.merge!(sigdata) unless sigdata.empty?
      throw(Signal::TAG, Signal.failed(reason, metadata:, backtrace: caller_locations(1)))
    end

    # Re-throws a failed peer Result's signal through this task. No-op when
    # `other` didn't fail.
    #
    # @param other [Result]
    # @param sigdata [Hash{Symbol => Object}] arbitrary metadata merged into {#metadata} before echoing
    # @option sigdata [Object] arbitrary entries merged via `metadata.merge!`
    # @return [void]
    # @raise [FrozenError]
    def throw!(other, **sigdata)
      raise FrozenError, "cannot throw signals" if frozen?

      return unless other.failed?

      metadata.merge!(sigdata) unless sigdata.empty?
      throw(Signal::TAG, Signal.echoed(other, metadata:, backtrace: caller_locations(1)))
    end

  end
end
