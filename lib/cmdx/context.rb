# frozen_string_literal: true

module CMDx
  # A hash-like context object that provides a flexible way to store and access
  # key-value pairs during task execution. Keys are automatically converted to
  # symbols for consistency.
  #
  # The Context class extends Forwardable to delegate common hash methods and
  # provides additional convenience methods for working with context data.
  class Context

    extend Forwardable

    attr_reader :table
    alias to_h table

    def_delegators :table, :each, :map

    # Creates a new Context instance from the given arguments.
    #
    # @param args [Hash, Object] arguments to initialize the context with
    # @option args [Object] :key the key-value pairs to store in the context
    #
    # @return [Context] a new Context instance
    #
    # @raise [ArgumentError] when args doesn't respond to `to_h` or `to_hash`
    #
    # @example
    #   context = Context.new(name: "John", age: 30)
    #   context[:name] # => "John"
    def initialize(args = {})
      @table =
        if args.respond_to?(:to_hash)
          args.to_hash
        elsif args.respond_to?(:to_h)
          args.to_h
        else
          raise ArgumentError, "must respond to `to_h` or `to_hash`"
        end.transform_keys(&:to_sym)
    end

    # Builds a Context instance, reusing existing unfrozen contexts when possible.
    #
    # @param context [Context, Object] the context to build from
    # @option context [Object] :key the key-value pairs to store in the context
    #
    # @return [Context] a Context instance, either new or reused
    #
    # @example
    #   existing = Context.new(name: "John")
    #   built = Context.build(existing) # reuses existing context
    #   built.object_id == existing.object_id # => true
    def self.build(context = {})
      if context.is_a?(self) && !context.frozen?
        context
      elsif context.respond_to?(:context)
        build(context.context)
      else
        new(context)
      end
    end

    # Retrieves a value from the context by key.
    #
    # @param key [String, Symbol] the key to retrieve
    #
    # @return [Object, nil] the value associated with the key, or nil if not found
    #
    # @example
    #   context = Context.new(name: "John")
    #   context[:name] # => "John"
    #   context["name"] # => "John" (automatically converted to symbol)
    def [](key)
      table[key.to_sym]
    end

    # Stores a key-value pair in the context.
    #
    # @param key [String, Symbol] the key to store
    # @param value [Object] the value to store
    #
    # @return [Object] the stored value
    #
    # @example
    #   context = Context.new
    #   context.store(:name, "John")
    #   context[:name] # => "John"
    def store(key, value)
      table[key.to_sym] = value
    end
    alias []= store

    # Fetches a value from the context by key, with optional default value.
    #
    # @param key [String, Symbol] the key to fetch
    # @param default [Object] the default value if key is not found
    #
    # @yield [key] a block to compute the default value
    #
    # @return [Object] the value associated with the key, or the default/default block result
    #
    # @example
    #   context = Context.new(name: "John")
    #   context.fetch(:name) # => "John"
    #   context.fetch(:age, 25) # => 25
    #   context.fetch(:city) { |key| "Unknown #{key}" } # => "Unknown city"
    def fetch(key, ...)
      table.fetch(key.to_sym, ...)
    end

    # Merges the given arguments into the current context, modifying it in place.
    #
    # @param args [Hash, Object] arguments to merge into the context
    # @option args [Object] :key the key-value pairs to merge
    #
    # @return [Context] self for method chaining
    #
    # @example
    #   context = Context.new(name: "John")
    #   context.merge!(age: 30, city: "NYC")
    #   context.to_h # => {name: "John", age: 30, city: "NYC"}
    def merge!(args = {})
      args.to_h.each { |key, value| self[key.to_sym] = value }
      self
    end

    # Deletes a key-value pair from the context.
    #
    # @param key [String, Symbol] the key to delete
    #
    # @yield [key] a block to handle the case when key is not found
    #
    # @return [Object, nil] the deleted value, or the block result if key not found
    #
    # @example
    #   context = Context.new(name: "John", age: 30)
    #   context.delete!(:age) # => 30
    #   context.delete!(:city) { |key| "Key #{key} not found" } # => "Key city not found"
    def delete!(key, &)
      table.delete(key.to_sym, &)
    end

    # Compares this context with another object for equality.
    #
    # @param other [Object] the object to compare with
    #
    # @return [Boolean] true if other is a Context with the same data
    #
    # @example
    #   context1 = Context.new(name: "John")
    #   context2 = Context.new(name: "John")
    #   context1 == context2 # => true
    def eql?(other)
      other.is_a?(self.class) && (to_h == other.to_h)
    end
    alias == eql?

    # Checks if the context contains a specific key.
    #
    # @param key [String, Symbol] the key to check
    #
    # @return [Boolean] true if the key exists in the context
    #
    # @example
    #   context = Context.new(name: "John")
    #   context.key?(:name) # => true
    #   context.key?(:age) # => false
    def key?(key)
      table.key?(key.to_sym)
    end

    # Digs into nested structures using the given keys.
    #
    # @param key [String, Symbol] the first key to dig with
    # @param keys [Array<String, Symbol>] additional keys for deeper digging
    #
    # @return [Object, nil] the value found by digging, or nil if not found
    #
    # @example
    #   context = Context.new(user: {profile: {name: "John"}})
    #   context.dig(:user, :profile, :name) # => "John"
    #   context.dig(:user, :profile, :age) # => nil
    def dig(key, *keys)
      table.dig(key.to_sym, *keys)
    end

    # Converts the context to a string representation.
    #
    # @return [String] a formatted string representation of the context data
    #
    # @example
    #   context = Context.new(name: "John", age: 30)
    #   context.to_s # => "name: John, age: 30"
    def to_s
      Utils::Format.to_str(to_h)
    end

    private

    # Handles method calls that don't match defined methods.
    # Supports assignment-style calls (e.g., `name=`) and key access.
    #
    # @param method_name [Symbol] the method name that was called
    # @param args [Array<Object>] arguments passed to the method
    # @param _kwargs [Hash] keyword arguments (unused)
    #
    # @yield [Object] optional block
    #
    # @return [Object] the result of the method call
    def method_missing(method_name, *args, **_kwargs, &)
      fetch(method_name) do
        store(method_name[0..-2], args.first) if method_name.end_with?("=")
      end
    end

    # Checks if the object responds to a given method.
    #
    # @param method_name [Symbol] the method name to check
    # @param include_private [Boolean] whether to include private methods
    #
    # @return [Boolean] true if the method can be called
    #
    # @example
    #   context = Context.new(name: "John")
    #   context.respond_to?(:name) # => true
    #   context.respond_to?(:age) # => false
    def respond_to_missing?(method_name, include_private = false)
      key?(method_name) || super
    end

  end
end
