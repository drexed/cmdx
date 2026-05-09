# frozen_string_literal: true

module CMDx
  # Shared data object passed through task execution. Wraps a symbol-keyed
  # hash; supports `ctx.foo`/`ctx.foo = 1`/`ctx.foo?` dynamic accessors via
  # {#method_missing}. Runtime freezes the root context during teardown so
  # nested subtasks can't mutate the outer task's state after completion.
  class Context

    include Enumerable

    class << self

      # Normalizes `context` into a Context instance. Passes through an
      # unfrozen Context unchanged (so nested tasks share state); unwraps
      # anything with `#context` (e.g. a Task); wraps hashes/hash-likes into
      # a new Context with symbolized keys.
      #
      # @param context [Context, #context, Hash, #to_h, #to_hash]
      # @return [Context]
      # @raise [ArgumentError] when `context` doesn't respond to `#to_h`/`#to_hash`
      def build(context = EMPTY_HASH)
        if context.is_a?(self) && !context.frozen?
          context
        elsif context.respond_to?(:context)
          build(context.context)
        else
          new(context)
        end
      end

    end

    # Enables strict mode — when true, dynamic readers via {#method_missing}
    # raise `NoMethodError` for unknown keys instead of returning `nil`.
    # Set by `Task#initialize` from `Task.settings.strict_context`.
    #
    # @return [Boolean]
    attr_accessor :strict

    # @param context [Hash, #to_h, #to_hash] source hash, keys are symbolized
    # @raise [ArgumentError] when `context` doesn't respond to `#to_h`/`#to_hash`
    def initialize(context = EMPTY_HASH)
      @table =
        if context.respond_to?(:to_hash)
          context.to_hash
        elsif context.respond_to?(:to_h)
          context.to_h
        else
          raise ArgumentError, "must respond to `to_h` or `to_hash`"
        end.transform_keys(&:to_sym)
    end

    # @return [Boolean] whether dynamic reads for unknown keys raise instead
    #   of returning `nil`
    def strict?
      !!@strict
    end

    # Stores `value` under `key`, symbolizing the key. Overwrites any
    # existing entry.
    #
    # @param key [Symbol, String]
    # @param value [Object]
    # @return [Object] the stored value
    def store(key, value)
      @table[key.to_sym] = value
    end
    alias []= store

    # Merges another context/hash-like into this one in place. Keys from
    # `context` win on conflict.
    #
    # @param context [Context, Hash, #to_h, #to_hash]
    # @return [Context] self for chaining
    def merge(context = EMPTY_HASH)
      other = self.class.build(context)
      @table.merge!(other.to_h)
      self
    end

    # Like {#merge} but recursive into Hash values: a nested Hash key collision
    # merges the two Hashes instead of replacing the left with the right.
    # Non-Hash values follow last-write-wins (`context` wins).
    #
    # @param context [Context, Hash, #to_h, #to_hash]
    # @return [Context] self for chaining
    def deep_merge(context = EMPTY_HASH)
      other = self.class.build(context)
      @table = compute_deep_merge(@table, other.to_h)
      self
    end

    # @param key [Symbol, String]
    # @return [Object, nil]
    def [](key)
      @table[key.to_sym]
    end

    # Hash-like fetch. Supports a default value, default block, or raises
    # `KeyError` just like `Hash#fetch`.
    #
    # @param key [Symbol, String]
    # @return [Object]
    def fetch(key, ...)
      @table.fetch(key.to_sym, ...)
    end

    # @param key [Symbol, String] top-level key (symbolized)
    # @param keys [Array<Object>] nested keys passed through untouched
    # @return [Object, nil]
    def dig(key, *keys)
      @table.dig(key.to_sym, *keys)
    end

    # Fetch-or-store. Returns the existing value, or stores and returns the
    # default (from block if given, else `value`).
    #
    # @param key [Symbol, String]
    # @param value [Object] fallback when no block is given
    # @yield [] invoked only when `key` is absent
    # @yieldreturn [Object] value to store
    # @return [Object]
    def retrieve(key, value = nil)
      nk = key.to_sym

      @table.fetch(nk) do
        @table[nk] = block_given? ? yield : value
      end
    end

    # @param key [Symbol, String]
    # @return [Boolean]
    def key?(key)
      @table.key?(key.to_sym)
    end

    # @return [Array<Symbol>]
    def keys
      @table.keys
    end

    # @return [Array<Object>]
    def values
      @table.values
    end

    # @return [Boolean]
    def empty?
      @table.empty?
    end

    # @return [Integer]
    def size
      @table.size
    end

    # @yield [key, value]
    # @return [Context, Enumerator]
    def each(&)
      @table.each(&)
    end

    # @yield [Symbol]
    # @return [Context, Enumerator]
    def each_key(&)
      @table.each_key(&)
    end

    # @yield [Object]
    # @return [Context, Enumerator]
    def each_value(&)
      @table.each_value(&)
    end

    # @param key [Symbol, String]
    # @yield [Symbol] optional default block, receives the symbolized key
    # @return [Object, nil] removed value
    def delete(key, &)
      @table.delete(key.to_sym, &)
    end

    # Removes every entry.
    #
    # @return [Context] self
    def clear
      @table.clear
      self
    end

    # Equal when `other` is a Context with the same underlying hash.
    #
    # @param other [Object]
    # @return [Boolean]
    def eql?(other)
      other.is_a?(self.class) && (to_h == other.to_h)
    end
    alias == eql?

    # @return [Integer]
    def hash
      @table.hash
    end

    # @return [Hash{Symbol => Object}] the underlying table (not a copy)
    def to_h
      @table
    end

    # JSON-friendly hash view. Aliases {#to_h} for conventional `as_json`
    # callers (e.g. Rails); values pass through unchanged — non-primitive
    # entries rely on their own `as_json` / `to_json`.
    #
    # @return [Hash{Symbol => Object}]
    def as_json(*)
      to_h
    end

    # Serializes the context to a JSON string. Symbol keys are emitted as
    # strings by the `json` stdlib.
    #
    # @param args [Array] forwarded to `Hash#to_json`
    # @return [String]
    def to_json(*args)
      to_h.to_json(*args)
    end

    # @return [String] space-separated `key=value.inspect` pairs
    def to_s
      @table.map { |k, v| "#{k}=#{v.inspect}" }.join(" ")
    end

    # Pattern-matching support for `case context in {...}`.
    #
    # @param keys [Array<Symbol>, nil] restrict the returned hash to these keys
    # @return [Hash{Symbol => Object}]
    def deconstruct_keys(keys)
      keys.nil? ? @table : @table.slice(*keys)
    end

    # Pattern-matching support for `case context in [...]`.
    #
    # @return [Array<Array(Symbol, Object)>]
    def deconstruct
      @table.to_a
    end

    # Returns a deep copy. Non-mutable scalars are shared; Hashes/Arrays are
    # recursively duplicated; other objects fall back to `#dup` (and then
    # to the original on `StandardError`).
    #
    # @return [Context]
    def deep_dup
      ctx = self.class.allocate
      ctx.instance_variable_set(:@table, compute_deep_dup(@table))
      ctx
    end

    # Freezes the context and its backing hash. Runtime calls this on the
    # root task's context during teardown.
    #
    # @return [Context] self
    def freeze
      @table.freeze
      super
    end

    private

    # Provides dynamic read/write/predicate access to context keys.
    #
    # - `ctx.name` — reads `@table[name]`, `nil` when absent (raises
    #   `UnknownAccessorError` when {#strict?} is true and the key is absent).
    # - `ctx.name = val` — stores `val` under `:name`.
    # - `ctx.name?` — truthy check for `@table[:name]`.
    #
    # @param method_name [Symbol] dynamic reader/writer/predicate name
    # @param args [Array<Object>] stores RHS for writers (`name=` → `[value]`)
    # @param _kwargs [Hash{Symbol => Object}] ignored (accepted for Ruby keyword forwarding)
    # @option _kwargs [Object] ignored
    # @raise [UnknownAccessorError] when {#strict?} is true and the key is missing
    # @api private
    def method_missing(method_name, *args, **_kwargs, &)
      if @table.key?(method_name)
        @table[method_name]
      elsif method_name.end_with?("=")
        @table[method_name[..-2].to_sym] = args.first
      elsif method_name.end_with?("?")
        !!@table[method_name[..-2].to_sym]
      elsif strict?
        raise UnknownAccessorError, "unknown context key #{method_name.inspect} (strict mode)"
      end
    end

    # @param method_name [Symbol]
    # @param include_private [Boolean] forwarded to Ruby's `respond_to?` lookup
    # @return [Boolean]
    def respond_to_missing?(method_name, include_private = false)
      @table.key?(method_name) || method_name.end_with?("=", "?") || super
    end

    # @param value [Object] nested value from the context table
    # @return [Object] recursively duplicated scalar/collection snapshot
    def compute_deep_dup(value)
      case value
      when Numeric, Symbol, TrueClass, FalseClass, NilClass
        value
      when Hash
        value.each_with_object({}) { |(k, v), acc| acc[k] = compute_deep_dup(v) }
      when Array
        value.map { |e| compute_deep_dup(e) }
      else
        begin
          value.dup
        rescue StandardError
          value
        end
      end
    end

    # @param lhs [Hash]
    # @param rhs [Hash]
    # @return [Hash] merged hash (recursive for nested `{Hash => Hash}` pairs)
    def compute_deep_merge(lhs, rhs)
      lhs.merge(rhs) do |_key, l, r|
        l.is_a?(Hash) && r.is_a?(Hash) ? compute_deep_merge(l, r) : r
      end
    end

  end
end
