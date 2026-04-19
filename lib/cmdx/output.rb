# frozen_string_literal: true

module CMDx
  # A single declared output. Runtime calls {#verify} after `work` to enforce
  # `:required`, apply `:default`, run `:coerce` types, apply `:transform`,
  # and run validators against the value the task wrote to `task.context[name]`.
  class Output

    attr_reader :name

    # @param name [Symbol, String] output key (symbolized)
    # @param options [Hash{Symbol => Object}] declaration options
    # @option options [String] :description (also accepts `:desc`)
    # @option options [Boolean] :required
    # @option options [Symbol, Proc, #call] :if
    # @option options [Symbol, Proc, #call] :unless
    # @option options [Symbol, Array, Hash, Proc] :coerce
    # @option options [Object, Symbol, Proc, #call] :default
    # @option options [Symbol, Proc, #call] :transform mutator applied after coercion
    def initialize(name, **options)
      @name    = name.to_sym
      @options = options.freeze
    end

    # @return [String, nil]
    def description
      @options[:description] || @options[:desc]
    end

    # @return [Object, Symbol, Proc, #call, nil]
    def default
      @options[:default]
    end

    # @return [Symbol, Proc, #call, nil]
    def transform
      @options[:transform]
    end

    # @return [Symbol, Proc, #call, nil]
    def condition_if
      @options[:if]
    end

    # @return [Symbol, Proc, #call, nil]
    def condition_unless
      @options[:unless]
    end

    # @return [Boolean]
    def required
      @options.fetch(:required, false)
    end

    # Evaluates required-ness against `task`, respecting `:if`/`:unless`.
    # When called without a task, returns the static `:required` flag.
    #
    # @param task [Task, nil]
    # @return [Boolean]
    def required?(task = nil)
      return false unless required
      return true if task.nil?
      return false unless Util.satisfied?(condition_if, condition_unless, task)

      true
    end

    # @return [Hash{Symbol => Object}] serialized schema for `outputs_schema`
    def to_h
      {
        name:,
        description:,
        required: required?,
        options: @options
      }
    end

    # Enforces the output contract against `task.context[name]` after `work` runs.
    #
    # Steps, in order:
    # 1. Reads the value from `task.context` and falls back to `:default` when nil.
    # 2. Adds a `cmdx.outputs.missing` error when required (respecting `:if`/`:unless`)
    #    and neither the key nor a default supplied a value.
    # 3. Short-circuits when the key was never written and no default exists.
    # 4. Runs `:coerce` types; aborts silently on {Coercions::Failure} (the coercion
    #    layer records its own error).
    # 5. Applies `:transform` to the coerced value.
    # 6. Runs validators, then writes the final value back to `task.context[name]`.
    #
    # @param task [Task] the running task whose context is inspected and mutated
    # @return [void]
    def verify(task)
      key_provided = task.context.key?(name)
      value        = task.context[name]
      value        = apply_default(task) if value.nil?

      if required?(task) && !key_provided && value.nil?
        task.errors.add(name, I18nProxy.t("cmdx.outputs.missing"))
        return
      end

      return if !key_provided && value.nil?

      coercions = task.class.coercions.extract(@options)
      value     = task.class.coercions.coerce(task, name, value, coercions)
      return if value.is_a?(Coercions::Failure)

      value = apply_transform(value, task) if transform

      validators = task.class.validators.extract(@options)
      task.class.validators.validate(task, name, value, validators)

      task.context[name] = value
    end

    private

    def apply_default(task)
      return if default.nil?

      case default
      when Symbol
        task.send(default)
      when Proc
        task.instance_exec(&default)
      else
        return default unless default.respond_to?(:call)

        default.call(task)
      end
    end

    def apply_transform(value, task)
      case transform
      when Symbol
        if value.respond_to?(transform)
          value.send(transform)
        else
          task.send(transform, value)
        end
      when Proc
        task.instance_exec(value, &transform)
      else
        return transform.call(value, task) if transform.respond_to?(:call)

        raise ArgumentError, "transform must be a Symbol, Proc, or respond to #call"
      end
    end

  end
end
