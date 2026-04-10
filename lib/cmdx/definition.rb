# frozen_string_literal: true

module CMDx
  # Immutable compiled view of a Task class's DSL declarations.
  # Merges parent definitions with per-class deltas on first access,
  # then caches the result on the class ivar.
  class Definition

    CALLBACK_PHASES = %i[
      before_validation before_execution
      on_complete on_interrupted on_executed
      on_success on_skipped on_failed on_good on_bad
    ].freeze

    # @return [Array<Attribute>]
    attr_reader :attributes

    # @return [Hash{Symbol => Array}]
    attr_reader :callbacks

    # @return [Array<Array>] middleware entries [[klass, opts], ...]
    attr_reader :middleware

    # @return [Hash{Symbol => Object}]
    attr_reader :coercions

    # @return [Hash{Symbol => Object}]
    attr_reader :validators

    # @return [Array<Hash>] returns entries [{name:, options:}, ...]
    attr_reader :returns

    # @return [RetryPolicy, nil]
    attr_reader :retry_policy

    # @return [Array<String>]
    attr_reader :rollback_on

    # @return [Array<String>]
    attr_reader :task_breakpoints

    # @return [Array<String>]
    attr_reader :workflow_breakpoints

    # @return [Array<String>]
    attr_reader :tags

    # @return [Boolean]
    attr_reader :backtrace

    # @return [Proc, nil]
    attr_reader :backtrace_cleaner

    # @return [Proc, nil]
    attr_reader :exception_handler

    # @return [Hash, nil]
    attr_reader :deprecate

    # @return [Boolean]
    attr_reader :dump_context

    # @return [Boolean]
    attr_reader :strong_context

    # @return [Boolean]
    attr_reader :workflow

    # @return [Array<Hash>]
    attr_reader :workflow_pipeline

    # @return [Logger, nil]
    attr_reader :logger

    # @return [Symbol, nil]
    attr_reader :log_level

    # @return [Object, nil]
    attr_reader :log_formatter

    # @return [Symbol, nil]
    attr_reader :on_failure

    # @rbs (**untyped) -> void
    def initialize(**opts)
      @attributes = opts.fetch(:attributes, []).freeze
      @callbacks = opts.fetch(:callbacks, {}).freeze
      @middleware = opts.fetch(:middleware, []).freeze
      @coercions = opts.fetch(:coercions, {}).freeze
      @validators = opts.fetch(:validators, {}).freeze
      @returns = opts.fetch(:returns, []).freeze
      @retry_policy = opts[:retry_policy]
      @rollback_on = opts.fetch(:rollback_on, []).freeze
      @task_breakpoints = opts.fetch(:task_breakpoints, []).freeze
      @workflow_breakpoints = opts.fetch(:workflow_breakpoints, []).freeze
      @tags = opts.fetch(:tags, []).freeze
      @backtrace = opts.fetch(:backtrace, false)
      @backtrace_cleaner = opts[:backtrace_cleaner]
      @exception_handler = opts[:exception_handler]
      @deprecate = opts[:deprecate]
      @dump_context = opts.fetch(:dump_context, false)
      @strong_context = opts.fetch(:strong_context, false)
      @workflow = opts.fetch(:workflow, false)
      @workflow_pipeline = opts.fetch(:workflow_pipeline, []).freeze
      @logger = opts[:logger]
      @log_level = opts[:log_level]
      @log_formatter = opts[:log_formatter]
      @on_failure = opts[:on_failure]
      freeze
    end

    # Fetches the compiled Definition for a Task class (cached).
    #
    # @param klass [Class]
    # @return [Definition]
    #
    # @rbs (Class klass) -> Definition
    def self.fetch(klass)
      klass.instance_variable_get(:@cmdx_definition) ||
        klass.instance_variable_set(:@cmdx_definition, compile(klass))
    end

    # Compiles a Definition by merging parent + class-level deltas.
    #
    # @param klass [Class]
    # @return [Definition]
    #
    # @rbs (Class klass) -> Definition
    def self.compile(klass)
      parent = if klass.superclass.is_a?(Class) && klass.superclass < CMDx::Task && klass.superclass != CMDx::Task
                 fetch(klass.superclass)
               else
                 root
               end

      attrs = merge_attributes(parent.attributes, ivar(klass, :@cmdx_attributes))
      callbacks = merge_callbacks(parent.callbacks, ivar(klass, :@cmdx_callbacks))
      middleware = parent.middleware + (ivar(klass, :@cmdx_middleware) || [])
      coercions = parent.coercions.merge(ivar(klass, :@cmdx_coercions) || {})
      validators = parent.validators.merge(ivar(klass, :@cmdx_validators) || {})
      returns = (parent.returns + (ivar(klass, :@cmdx_returns) || [])).uniq { |r| r[:name] }

      new(
        attributes: attrs,
        callbacks: callbacks,
        middleware: middleware,
        coercions: coercions,
        validators: validators,
        returns: returns,
        retry_policy: ivar(klass, :@cmdx_retry_policy) || parent.retry_policy,
        rollback_on: ivar(klass, :@cmdx_rollback_on) || parent.rollback_on,
        task_breakpoints: ivar(klass, :@cmdx_task_breakpoints) || parent.task_breakpoints,
        workflow_breakpoints: ivar(klass, :@cmdx_workflow_breakpoints) || parent.workflow_breakpoints,
        tags: (parent.tags + Array(ivar(klass, :@cmdx_tags))).uniq,
        backtrace: ivar_or(klass, :@cmdx_backtrace, parent.backtrace),
        backtrace_cleaner: ivar(klass, :@cmdx_backtrace_cleaner) || parent.backtrace_cleaner,
        exception_handler: ivar(klass, :@cmdx_exception_handler) || parent.exception_handler,
        deprecate: ivar(klass, :@cmdx_deprecate) || parent.deprecate,
        dump_context: ivar_or(klass, :@cmdx_dump_context, parent.dump_context),
        strong_context: ivar_or(klass, :@cmdx_strong_context, parent.strong_context),
        workflow: (klass.respond_to?(:cmdx_workflow?) && klass.cmdx_workflow?) || parent.workflow,
        workflow_pipeline: klass.respond_to?(:cmdx_workflow_pipeline) && klass.cmdx_workflow_pipeline.any? ? klass.cmdx_workflow_pipeline : parent.workflow_pipeline,
        logger: ivar(klass, :@cmdx_logger) || parent.logger,
        log_level: ivar(klass, :@cmdx_log_level) || parent.log_level,
        log_formatter: ivar(klass, :@cmdx_log_formatter) || parent.log_formatter,
        on_failure: ivar(klass, :@cmdx_on_failure) || parent.on_failure
      )
    end

    # Root definition built from global Configuration defaults.
    #
    # @return [Definition]
    #
    # @rbs () -> Definition
    def self.root
      config = CMDx.configuration
      builtins = builtin_registries
      new(
        coercions: builtins[:coercions].merge(config.coercions),
        validators: builtins[:validators].merge(config.validators),
        middleware: config.middlewares.dup,
        callbacks: config.callbacks.transform_values(&:dup),
        task_breakpoints: config.task_breakpoints,
        workflow_breakpoints: config.workflow_breakpoints,
        rollback_on: config.rollback_on,
        backtrace: config.backtrace,
        backtrace_cleaner: config.backtrace_cleaner,
        logger: config.logger,
        log_level: config.log_level,
        log_formatter: config.log_formatter
      )
    end

    # Built-in coercion and validator registries.
    #
    # @return [Hash]
    #
    # @rbs () -> Hash[Symbol, Hash[Symbol, untyped]]
    def self.builtin_registries
      {
        coercions: {
          array: Coercions::Array, big_decimal: Coercions::BigDecimal,
          boolean: Coercions::Boolean, complex: Coercions::Complex,
          date: Coercions::Date, date_time: Coercions::DateTime,
          float: Coercions::Float, hash: Coercions::Hash,
          integer: Coercions::Integer, rational: Coercions::Rational,
          string: Coercions::String, symbol: Coercions::Symbol,
          time: Coercions::Time
        },
        validators: {
          absence: Validators::Absence, exclusion: Validators::Exclusion,
          format: Validators::Format, inclusion: Validators::Inclusion,
          length: Validators::Length, numeric: Validators::Numeric,
          presence: Validators::Presence
        }
      }
    end

    # @rbs (Array[Attribute] parent_attrs, Array[Attribute]? child_attrs) -> Array[Attribute]
    def self.merge_attributes(parent_attrs, child_attrs)
      return parent_attrs unless child_attrs&.any?

      merged = parent_attrs.to_h { |a| [a.reader_name, a] }
      child_attrs.each { |a| merged[a.reader_name] = a }
      merged.values
    end

    # @rbs (Hash[Symbol, Array] parent_cbs, Hash[Symbol, Array]? child_cbs) -> Hash[Symbol, Array]
    def self.merge_callbacks(parent_cbs, child_cbs)
      return parent_cbs unless child_cbs&.any?

      merged = parent_cbs.transform_values(&:dup)
      child_cbs.each do |phase, entries|
        merged[phase] = (merged[phase] || []) + entries
      end
      merged
    end

    # @rbs (Class klass, Symbol ivar_name) -> untyped
    def self.ivar(klass, ivar_name)
      klass.instance_variable_defined?(ivar_name) ? klass.instance_variable_get(ivar_name) : nil
    end

    # @rbs (Class klass, Symbol ivar_name, untyped fallback) -> untyped
    def self.ivar_or(klass, ivar_name, fallback)
      klass.instance_variable_defined?(ivar_name) ? klass.instance_variable_get(ivar_name) : fallback
    end

    private_class_method :merge_attributes, :merge_callbacks, :ivar, :ivar_or

  end
end
