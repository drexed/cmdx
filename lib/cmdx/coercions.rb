# frozen_string_literal: true

module CMDx
  # Registry of named type coercions applied to input/output values. Ships
  # with built-ins for `:array`, `:big_decimal`, `:boolean`, `:complex`,
  # `:date`, `:date_time`, `:float`, `:hash`, `:integer`, `:rational`,
  # `:string`, `:symbol`, `:time`. Coercion handlers return the coerced
  # value on success, or a {Failure} carrying an i18n message on failure.
  class Coercions

    # Sentinel returned by a coercion when the value can't be converted.
    # Runtime records the message as a validation error against the attribute.
    Failure = Data.define(:message)

    attr_reader :registry

    def initialize
      @registry = {
        array: Coercions::Array,
        big_decimal: Coercions::BigDecimal,
        boolean: Coercions::Boolean,
        complex: Coercions::Complex,
        date: Coercions::Date,
        date_time: Coercions::DateTime,
        float: Coercions::Float,
        hash: Coercions::Hash,
        integer: Coercions::Integer,
        rational: Coercions::Rational,
        string: Coercions::String,
        symbol: Coercions::Symbol,
        time: Coercions::Time
      }
    end

    def initialize_copy(source)
      @registry = source.registry.dup
    end

    # Registers a named coercion, overwriting any existing entry with the
    # same name.
    #
    # @param name [Symbol]
    # @param callable [#call, nil] pass either this or a block
    # @yield (see built-in coercion signatures — `call(value, options = {})`)
    # @return [Coercions] self for chaining
    # @raise [ArgumentError] when both `callable` and a block are given, or
    #   when the resolved coercion isn't callable
    def register(name, callable = nil, &block)
      raise ArgumentError, "provide either a callable or a block, not both" if callable && block

      coercion = callable || block
      raise ArgumentError, "coercion must respond to #call" unless coercion.respond_to?(:call)

      registry[name.to_sym] = coercion
      self
    end

    # @param name [Symbol]
    # @return [Coercions] self for chaining
    def deregister(name)
      registry.delete(name.to_sym)
      self
    end

    # @param name [Symbol]
    # @return [#call] the registered coercion
    # @raise [ArgumentError] when `name` isn't registered
    def lookup(name)
      registry[name] || begin
        raise ArgumentError, "unknown coercion: #{name}"
      end
    end

    # Normalizes the `:coerce` declaration on an input/output into a list of
    # `[handler, opts]` pairs. Accepts a Symbol, Array, Hash, or any
    # callable.
    #
    # @param options [Hash{Symbol => Object}] declaration options
    # @return [Array<Array(Object, Hash)>] pairs of handler + per-handler options
    # @raise [ArgumentError] when `:coerce` is an unsupported format
    def extract(options)
      return EMPTY_ARRAY if options.empty?

      raw = options[:coerce]
      return EMPTY_ARRAY if raw.nil? || raw == EMPTY_ARRAY

      case raw
      when ::Symbol
        [[raw, EMPTY_HASH]]
      when ::Array
        raw.map { |t| normalize_entry(t) }
      when ::Hash
        raw.map { |k, v| [k, v == true ? EMPTY_HASH : v] }
      else
        return [[raw, EMPTY_HASH]] if raw.respond_to?(:call)

        raise ArgumentError, "unsupported type format: #{raw.inspect}"
      end
    end

    # @return [Boolean]
    def empty?
      registry.empty?
    end

    # @return [Integer]
    def size
      registry.size
    end

    # Applies each coercion rule to `value`. Returns the first successful
    # coercion. When every rule fails and more than one was declared (and
    # none were inline callables), the aggregated "into_any" message is
    # recorded; otherwise the last individual failure is used.
    #
    # @param task [Task] used for inline `Symbol`/`Proc` handlers and error recording
    # @param name [Symbol] attribute name for error reporting
    # @param value [Object] value to coerce
    # @param rules [Array<Array(Object, Hash)>] from {#extract}
    # @return [Object, Failure] coerced value, or `Failure` when every rule failed
    def coerce(task, name, value, rules)
      return value if rules.empty?

      last_failure = nil
      any_inline = false

      rules.each do |handler, opts|
        result =
          if handler.is_a?(::Symbol) && registry.key?(handler)
            lookup(handler).call(value, **opts)
          else
            any_inline = true
            Coercions::Coerce.call(task, value, handler)
          end

        return result unless result.is_a?(Failure)

        last_failure = result
      end

      if rules.size > 1 && !any_inline
        type_names   = rules.map { |h, _| I18nProxy.t("cmdx.types.#{h}") }.join(", ")
        last_failure = Failure.new(I18nProxy.t("cmdx.coercions.into_any", types: type_names))
      end

      task.errors.add(name, last_failure.message)
      last_failure
    end

    private

    def normalize_entry(entry)
      case entry
      when ::Symbol, ::Proc
        [entry, EMPTY_HASH]
      else
        return [entry, EMPTY_HASH] if entry.respond_to?(:call)

        raise ArgumentError, "unsupported coerce entry: #{entry.inspect}"
      end
    end

  end
end
