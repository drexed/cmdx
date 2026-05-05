# frozen_string_literal: true

module CMDx
  # A single declared output. Runtime calls {#verify} after `work` to enforce
  # presence on `task.context[name]` (every declared output is implicitly
  # required) and to apply `:default`. `:if`/`:unless` gate verification entirely.
  class Output

    attr_reader :name

    # @param name [Symbol, String] output key (symbolized)
    # @param options [Hash{Symbol => Object}] declaration options
    # @option options [String] :description (also accepts `:desc`)
    # @option options [Symbol, Proc, #call] :if
    # @option options [Symbol, Proc, #call] :unless
    # @option options [Object, Symbol, Proc, #call] :default
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
    def condition_if
      @options[:if]
    end

    # @return [Symbol, Proc, #call, nil]
    def condition_unless
      @options[:unless]
    end

    # @return [Hash{Symbol => Object}] serialized schema for `outputs_schema`
    def to_h
      {
        name:,
        description:,
        options: @options
      }
    end

    # JSON-friendly hash view. Aliases {#to_h} for conventional `as_json`
    # callers (e.g. Rails).
    #
    # @return [Hash{Symbol => Object}]
    def as_json(*)
      to_h
    end

    # Serializes the output schema to a JSON string. Non-primitive entries in
    # `:options` (Procs, arbitrary callables) emit via their stdlib `to_json`
    # defaults.
    #
    # @param args [Array] forwarded to `Hash#to_json`
    # @return [String]
    def to_json(*args)
      to_h.to_json(*args)
    end

    # Enforces the output contract against `task.context[name]` after `work` runs.
    #
    # Steps, in order:
    # 1. Skips entirely when `:if`/`:unless` excludes it.
    # 2. Reads the value from `task.context` and falls back to `:default` when nil.
    # 3. Adds a `cmdx.outputs.missing` error when neither the key nor a default
    #    supplied a value (every declared output is implicitly required).
    # 4. Writes the resolved value back to `task.context[name]`.
    #
    # @param task [Task] the running task whose context is inspected and mutated
    # @return [void]
    def verify(task)
      return unless Util.satisfied?(condition_if, condition_unless, task)

      key_provided = task.context.key?(name)
      value        = task.context[name]
      value        = apply_default(task) if value.nil?

      if !key_provided && value.nil?
        task.errors.add(name, I18nProxy.t("cmdx.outputs.missing"))
        return
      end

      task.context[name] = value
    end

    private

    # @param task [Task]
    # @return [Object, nil]
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

  end
end
