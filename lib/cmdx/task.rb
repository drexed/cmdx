# frozen_string_literal: true

module CMDx
  # Command object: declare inputs with +required+ / +optional+, implement +work+.
  class Task

    # @return [Session, nil]
    attr_reader :session

    # @return [Hash{Symbol => Object}]
    attr_reader :attributes

    class << self

      # @param sub [Class]
      # @return [void]
      def inherited(sub)
        super
        reset_cmdx_definition!(sub)
      end

      # @param klass [Class]
      # @return [void]
      def reset_cmdx_definition!(klass = self)
        klass.remove_instance_variable(:@cmdx_definition) if klass.instance_variable_defined?(:@cmdx_definition)
      end

      # @return [Definition]
      def definition
        Definition.fetch(self)
      end

      # @return [Boolean]
      def cmdx_workflow?
        false
      end

      # @return [Array<Hash>]
      def cmdx_workflow_pipeline
        @cmdx_workflow_pipeline ||= []
      end

      # @return [Hash]
      def cmdx_extension_delta
        @cmdx_extension_delta ||= { coercions: {}, validators: {}, middleware: [] }
      end

      # @return [Array<AttributeSpec>]
      def cmdx_declared_attributes
        @cmdx_declared_attributes ||= []
      end

      # @return [Array<Symbol>]
      def cmdx_returns
        @cmdx_returns ||= []
      end

      # @return [Hash{Symbol => Array}]
      def cmdx_callback_deltas
        @cmdx_callback_deltas ||= Hash.new { |h, k| h[k] = [] }
      end

      # @return [String]
      def task_kind
        cmdx_workflow? ? "Workflow" : "Task"
      end

      # @param input [Hash]
      # @param trace [Trace, nil]
      # @param raise_on_fault [Boolean]
      # @return [ExecutionResult]
      def execute(input = {}, trace: nil, raise_on_fault: false, **kwargs, &block)
        merged = merge_input(input, kwargs)
        handler = new(merged, trace: trace)
        result = Executor.new(handler).run(raise_on_fault: raise_on_fault)
        yield result if block_given?
        result
      end

      # @param input [Hash]
      # @param trace [Trace, nil]
      # @param kwargs [Hash]
      # @return [ExecutionResult]
      def execute!(input = {}, trace: nil, **kwargs, &block)
        execute(input, trace: trace, raise_on_fault: true, **kwargs, &block)
      end

      # @param input [Object]
      # @param kwargs [Hash]
      # @return [Hash{Symbol => Object}]
      def merge_input(input, kwargs)
        base = input.is_a?(Hash) ? input : input.to_h
        base.merge(kwargs).transform_keys(&:to_sym)
      end

      # @param opts [Hash]
      # @return [void]
      def settings(**opts)
        deprecate(opts[:deprecate]) if opts.key?(:deprecate)
        tags(*opts[:tags]) if opts[:tags]
      end

      # @param type [Symbol]
      # @param args [Array]
      # @param kwargs [Hash]
      # @return [void]
      def register(type, *args, **kwargs)
        case type
        when :middleware
          cmdx_extension_delta[:middleware] << [args.first, kwargs]
        when :coercion
          cmdx_extension_delta[:coercions][args.first.to_sym] = ExtensionSet.wrap_coercion(args.last)
        when :validator
          cmdx_extension_delta[:validators][args.first.to_sym] = ExtensionSet.wrap_validator(args.last)
        else
          raise ArgumentError, "unknown registry type #{type.inspect}"
        end
        reset_cmdx_definition!
      end

      # @param names [Array]
      # @param options [Hash]
      # @return [void]
      def attributes(*names, **options)
        names.flatten.each { |n| declare_attribute(n, required: false, **options) }
      end
      alias attribute attributes

      # @param names [Array]
      # @param options [Hash]
      # @return [void]
      def optional(*names, **options)
        names.flatten.each { |n| declare_attribute(n, required: false, **options) }
      end

      # @param names [Array]
      # @param options [Hash]
      # @return [void]
      def required(*names, **options)
        names.flatten.each { |n| declare_attribute(n, required: true, **options) }
      end

      # @param names [Array<Symbol>]
      # @return [void]
      def returns(*names)
        cmdx_returns.concat(names.map(&:to_sym))
        reset_cmdx_definition!
      end

      # @param count [Integer]
      # @param opts [Hash]
      # @return [void]
      def retries(count, **opts)
        @cmdx_retry_policy = RetryPolicy.new(
          max_attempts: count,
          retry_on: Array(opts[:retry_on] || []),
          jitter: opts[:retry_jitter]
        )
        reset_cmdx_definition!
      end

      # @param statuses [Array<Symbol, String>]
      # @return [void]
      def rollback_on(*statuses)
        @cmdx_rollback_on = Utils::Normalize.statuses(statuses).map(&:to_sym)
        reset_cmdx_definition!
      end

      # @param statuses [Array]
      # @return [void]
      def task_breakpoints(*statuses)
        @cmdx_task_breakpoints = Utils::Normalize.statuses(statuses).map(&:to_sym)
        reset_cmdx_definition!
      end

      # @param statuses [Array]
      # @return [void]
      def workflow_breakpoints(*statuses)
        @cmdx_workflow_breakpoints = Utils::Normalize.statuses(statuses).map(&:to_sym)
        reset_cmdx_definition!
      end

      # @param tags [Array<Symbol>]
      # @return [void]
      def tags(*tags)
        @cmdx_tags ||= []
        @cmdx_tags |= tags.flatten.map(&:to_sym)
        reset_cmdx_definition!
      end

      # @param value [Object]
      # @return [void]
      def deprecate(value)
        @cmdx_deprecate = value
        reset_cmdx_definition!
      end

      # @param flag [Boolean]
      # @return [void]
      def strong_context(flag = true)
        @cmdx_strong_context = flag
        reset_cmdx_definition!
      end

      # @param flag [Boolean]
      # @return [void]
      def dump_context(flag = true)
        @cmdx_dump_context = flag
        reset_cmdx_definition!
      end

      # @param flag [Boolean]
      # @return [void]
      def freeze_results(flag = true)
        @cmdx_freeze_results = flag
        reset_cmdx_definition!
      end

      # @param flag [Boolean]
      # @return [void]
      def backtrace(flag = true)
        @cmdx_backtrace = flag
        reset_cmdx_definition!
      end

      # @param proc [Proc]
      # @return [void]
      def backtrace_cleaner(proc)
        @cmdx_backtrace_cleaner = proc
        reset_cmdx_definition!
      end

      # @param proc [Proc]
      # @return [void]
      def exception_handler(proc)
        @cmdx_exception_handler = proc
        reset_cmdx_definition!
      end

      Definition::CALLBACK_PHASES.each do |phase|
        define_method(phase) do |*methods, **options, &block|
          methods.each { |m| cmdx_callback_deltas[phase] << [m, options] }
          cmdx_callback_deltas[phase] << [block, options] if block
          Task.reset_cmdx_definition!(self)
        end
      end

      private

      # @param name [Symbol]
      # @param required [Boolean]
      # @param options [Hash]
      # @return [void]
      def declare_attribute(name, required:, **options)
        type_keys = type_keys_from(options)
        validators = validator_entries_from(options)
        coerce_opts = coerce_options_only(options)
        reader = (options[:as] || name).to_sym

        cmdx_declared_attributes << AttributeSpec.new(
          name: name.to_sym,
          required: required,
          type_keys: type_keys,
          reader_name: reader,
          options: coerce_opts,
          validators: validators
        )
        define_attribute_reader!(reader)
        reset_cmdx_definition!
      end

      # @param options [Hash]
      # @return [Array<Symbol>]
      def type_keys_from(options)
        t = options[:type] || options[:types]
        return [] if t.nil?

        Array(t).map(&:to_sym)
      end

      # @param options [Hash]
      # @return [Array<Hash>]
      def validator_entries_from(options)
        list = []
        %i[presence absence format inclusion exclusion length numeric].each do |k|
          next unless options.key?(k)

          v = options[k]
          list << { name: k, options: v.is_a?(Hash) ? v : { k => v } }
        end
        list
      end

      # @param options [Hash]
      # @return [Hash]
      def coerce_options_only(options)
        options.except(
          :type, :types, :required, :optional, :as,
          :presence, :absence, :format, :inclusion, :exclusion, :length, :numeric,
          :if, :unless, :allow_nil
        )
      end

      # @param reader_name [Symbol]
      # @return [void]
      def define_attribute_reader!(reader_name)
        return if method_defined?(reader_name)
        return if private_method_defined?(reader_name)

        class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{reader_name}
            @attributes[:#{reader_name}]
          end
        RUBY
      end

    end

    # @param input [Hash]
    # @param trace [Trace, nil]
    def initialize(input = {}, trace: nil)
      @raw_input = self.class.merge_input(input, {})
      @execution_trace = trace
      @attributes = {}
      @session = nil
    end

    # @return [Hash{Symbol => Object}]
    def raw_input_hash
      @raw_input
    end

    # @return [Trace, nil]
    attr_reader :execution_trace

    # @param sess [Session]
    # @return [void]
    def setup_session!(sess)
      @session = sess
    end

    # @return [Context]
    def context
      session.context
    end

    # @return [Errors]
    def errors
      session.errors
    end

    # @param name [Symbol]
    # @param value [Object]
    # @return [void]
    def write_attribute!(name, value)
      @attributes[name.to_sym] = value
    end

    # @param raise_on_fault [Boolean]
    # @return [ExecutionResult]
    def execute(raise_on_fault: false)
      Executor.new(self).run(raise_on_fault: raise_on_fault)
    end

    # @return [ExecutionResult]
    def execute!
      execute(raise_on_fault: true)
    end

    # @raise [UndefinedMethodError]
    # @return [void]
    def work
      raise UndefinedMethodError, "undefined method #{self.class.name}#work"
    end

    # @return [void]
    def success!(...)
      outcome.success!(...)
    end

    # @return [void]
    def skip!(...)
      outcome.skip!(...)
    end

    # @return [void]
    def fail!(...)
      outcome.fail!(...)
    end

    # @return [Outcome]
    def outcome
      session&.outcome || raise("task is not executing")
    end

    # @return [Logger]
    def logger
      session&.logger || CMDx.configuration.logger
    end

    # @return [Hash{Symbol => Object}]
    def to_h
      {
        trace_id: session&.trace&.id,
        type: self.class.task_kind,
        class: self.class.name,
        tags: self.class.definition.tags,
        dry_run: false
      }
    end

  end
end
