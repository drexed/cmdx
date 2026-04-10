# frozen_string_literal: true

module CMDx
  # Immutable compiled view of a task class (attributes, extensions, callbacks).
  class Definition

    CALLBACK_PHASES = %i[
      before_validation before_execution
      on_complete on_interrupted on_executed
      on_success on_skipped on_failed on_good on_bad
    ].freeze

    # @return [ExtensionSet]
    attr_reader :extensions

    # @return [Array<AttributeSpec>]
    attr_reader :attribute_specs

    # @return [Array<Symbol>]
    attr_reader :returns

    # @return [Hash{Symbol => Array<Array>}]
    attr_reader :callbacks

    # @return [RetryPolicy, nil]
    attr_reader :retry_policy

    # @return [Array<Symbol>]
    attr_reader :rollback_on

    # @return [Array<Symbol>]
    attr_reader :task_breakpoints

    # @return [Array<Symbol>]
    attr_reader :workflow_breakpoints

    # @return [Boolean]
    attr_reader :dump_context

    # @return [Boolean]
    attr_reader :freeze_results

    # @return [Boolean]
    attr_reader :backtrace

    # @return [Proc, nil]
    attr_reader :backtrace_cleaner

    # @return [Proc, nil]
    attr_reader :exception_handler

    # @return [Symbol, Proc, Boolean, nil]
    attr_reader :deprecate

    # @return [Array<Symbol>]
    attr_reader :tags

    # @return [Boolean]
    attr_reader :strong_context

    # @return [Array]
    attr_reader :workflow_pipeline

    # @return [Boolean]
    attr_reader :workflow

    # @return [MiddlewareStack]
    attr_reader :middleware_stack

    # @param extensions [ExtensionSet]
    # @param attribute_specs [Array<AttributeSpec>]
    # @param returns [Array<Symbol>]
    # @param callbacks [Hash]
    # @param retry_policy [RetryPolicy, nil]
    # @param rollback_on [Array<Symbol>]
    # @param task_breakpoints [Array<Symbol>]
    # @param workflow_breakpoints [Array<Symbol>]
    # @param dump_context [Boolean]
    # @param freeze_results [Boolean]
    # @param backtrace [Boolean]
    # @param backtrace_cleaner [Proc, nil]
    # @param exception_handler [Proc, nil]
    # @param deprecate [Object]
    # @param tags [Array<Symbol>]
    # @param strong_context [Boolean]
    # @param workflow [Boolean]
    # @param workflow_pipeline [Array]
    def initialize( # rubocop:disable Metrics/ParameterLists
      extensions:,
      attribute_specs:,
      returns:,
      callbacks:,
      retry_policy:,
      rollback_on:,
      task_breakpoints:,
      workflow_breakpoints:,
      dump_context:,
      freeze_results:,
      backtrace:,
      backtrace_cleaner:,
      exception_handler:,
      deprecate:,
      tags:,
      strong_context: false,
      workflow: false,
      workflow_pipeline: []
    )
      @extensions = extensions
      @attribute_specs = attribute_specs.freeze
      @returns = returns.freeze
      @callbacks = callbacks.freeze
      @retry_policy = retry_policy
      @rollback_on = rollback_on.freeze
      @task_breakpoints = task_breakpoints.freeze
      @workflow_breakpoints = workflow_breakpoints.freeze
      @dump_context = dump_context
      @freeze_results = freeze_results
      @backtrace = backtrace
      @backtrace_cleaner = backtrace_cleaner
      @exception_handler = exception_handler
      @deprecate = deprecate
      @tags = tags.freeze
      @strong_context = strong_context
      @workflow = workflow
      @workflow_pipeline = workflow_pipeline.freeze
      @middleware_stack = MiddlewareStack.new(extensions.middleware)
      freeze
    end

    # @param config [Configuration]
    # @return [Definition]
    def self.root(config)
      callbacks = CALLBACK_PHASES.to_h { |p| [p, [].freeze] }
      new(
        extensions: config.extensions,
        attribute_specs: [],
        returns: [],
        callbacks:,
        retry_policy: nil,
        rollback_on: config.rollback_on.map(&:to_sym),
        task_breakpoints: config.task_breakpoints.map(&:to_sym),
        workflow_breakpoints: config.workflow_breakpoints.map(&:to_sym),
        dump_context: config.dump_context,
        freeze_results: config.freeze_results,
        backtrace: config.backtrace,
        backtrace_cleaner: config.backtrace_cleaner,
        exception_handler: config.exception_handler,
        deprecate: nil,
        tags: [],
        strong_context: false,
        workflow: false,
        workflow_pipeline: []
      )
    end

    # @param klass [Class]
    # @return [Definition]
    def self.fetch(klass)
      klass.instance_variable_get(:@cmdx_definition) || klass.instance_variable_set(:@cmdx_definition, compile(klass))
    end

    # @param klass [Class]
    # @return [Definition]
    def self.compile(klass)
      parent =
        if klass.superclass.is_a?(Class) && klass.superclass < CMDx::Task && klass.superclass != CMDx::Task
          fetch(klass.superclass)
        else
          CMDx.configuration.base_definition
        end

      delta = klass.cmdx_extension_delta
      extensions = parent.extensions.merge(
        ExtensionSet.new(
          coercions: delta[:coercions] || {},
          validators: delta[:validators] || {},
          middleware: delta[:middleware] || []
        )
      )

      attrs = parent.attribute_specs.to_h { |s| [s.reader_name, s] }
      klass.cmdx_declared_attributes.each { |s| attrs[s.reader_name] = s }
      attribute_specs = attrs.values

      returns = (parent.returns + klass.cmdx_returns).uniq

      callbacks = parent.callbacks.transform_values(&:dup)
      klass.cmdx_callback_deltas.each do |phase, entries|
        cur = callbacks[phase] || []
        callbacks[phase] = cur + entries
      end

      callbacks.transform_values!(&:freeze)

      retry_policy = ivar_or(klass, :@cmdx_retry_policy, parent.retry_policy)

      new(
        extensions:,
        attribute_specs:,
        returns:,
        callbacks:,
        retry_policy:,
        rollback_on: ivar_or(klass, :@cmdx_rollback_on, parent.rollback_on),
        task_breakpoints: ivar_or(klass, :@cmdx_task_breakpoints, parent.task_breakpoints),
        workflow_breakpoints: ivar_or(klass, :@cmdx_workflow_breakpoints, parent.workflow_breakpoints),
        dump_context: ivar_or(klass, :@cmdx_dump_context, parent.dump_context),
        freeze_results: ivar_or(klass, :@cmdx_freeze_results, parent.freeze_results),
        backtrace: ivar_or(klass, :@cmdx_backtrace, parent.backtrace),
        backtrace_cleaner: ivar_or(klass, :@cmdx_backtrace_cleaner, parent.backtrace_cleaner),
        exception_handler: ivar_or(klass, :@cmdx_exception_handler, parent.exception_handler),
        deprecate: ivar_or(klass, :@cmdx_deprecate, parent.deprecate),
        tags: (parent.tags + Array(ivar_or(klass, :@cmdx_tags, []))).uniq,
        strong_context: ivar_or(klass, :@cmdx_strong_context, parent.strong_context),
        workflow: klass.cmdx_workflow? || parent.workflow,
        workflow_pipeline: klass.cmdx_workflow? ? klass.cmdx_workflow_pipeline.dup.freeze : parent.workflow_pipeline
      )
    end

    # @param klass [Class]
    # @param ivar [Symbol]
    # @param fallback [Object]
    # @return [Object]
    def self.ivar_or(klass, ivar, fallback)
      klass.instance_variable_defined?(ivar) ? klass.instance_variable_get(ivar) : fallback
    end

  end
end
