# frozen_string_literal: true

module CMDx
  # Flexible struct-like object with symbol-based attribute access and dynamic assignment.
  #
  # LazyStruct provides a hash-like object that automatically converts string keys to symbols
  # and supports both hash-style and method-style attribute access. It's designed for
  # storing and accessing dynamic attributes with lazy evaluation and flexible assignment patterns.
  class LazyStruct

    # Creates a new LazyStruct instance with the provided attributes.
    #
    # @param args [Hash, #to_h] initial attributes for the struct
    #
    # @return [LazyStruct] a new LazyStruct instance
    #
    # @raise [ArgumentError] if args doesn't respond to to_h
    #
    # @example Create with hash attributes
    #   struct = LazyStruct.new(name: "John", age: 30)
    #   struct.name #=> "John"
    #
    # @example Create with hash-like object
    #   struct = LazyStruct.new(OpenStruct.new(status: "active"))
    #   struct.status #=> "active"
    def initialize(args = {})
      unless args.respond_to?(:to_h)
        raise ArgumentError,
              "must be respond to `to_h`"
      end

      @table = args.to_h.transform_keys { |k| symbolized_key(k) }
    end

    # Retrieves the value for the specified key.
    #
    # @param key [Symbol, String] the key to look up
    #
    # @return [Object, nil] the value associated with the key, or nil if not found
    #
    # @example Access attribute by symbol
    #   struct = LazyStruct.new(name: "John")
    #   struct[:name] #=> "John"
    #
    # @example Access attribute by string
    #   struct[:name] #=> "John"
    #   struct["name"] #=> "John"
    def [](key)
      table[symbolized_key(key)]
    end

    # Retrieves the value for the specified key or returns/yields a default.
    #
    # @param key [Symbol, String] the key to look up
    # @param args [Array] additional arguments passed to Hash#fetch
    #
    # @return [Object] the value associated with the key, or default value
    #
    # @raise [KeyError] if key is not found and no default is provided
    #
    # @example Fetch with default value
    #   struct = LazyStruct.new(name: "John")
    #   struct.fetch!(:age, 25) #=> 25
    #
    # @example Fetch with block default
    #   struct.fetch!(:missing) { "default" } #=> "default"
    def fetch!(key, ...)
      table.fetch(symbolized_key(key), ...)
    end

    # Stores a value for the specified key.
    #
    # @param key [Symbol, String] the key to store the value under
    # @param value [Object] the value to store
    #
    # @return [Object] the stored value
    #
    # @example Store a value
    #   struct = LazyStruct.new
    #   struct.store!(:name, "John") #=> "John"
    #   struct.name #=> "John"
    def store!(key, value)
      table[symbolized_key(key)] = value
    end
    alias []= store!

    # Merges the provided arguments into the struct's attributes.
    #
    # @param args [Hash, #to_h] attributes to merge into the struct
    #
    # @return [LazyStruct] self for method chaining
    #
    # @example Merge attributes
    #   struct = LazyStruct.new(name: "John")
    #   struct.merge!(age: 30, city: "NYC")
    #   struct.age #=> 30
    def merge!(args = {})
      args.to_h.each { |key, value| store!(symbolized_key(key), value) }
      self
    end

    # Deletes the specified key from the struct.
    #
    # @param key [Symbol, String] the key to delete
    # @param block [Proc] optional block to yield if key is not found
    #
    # @return [Object, nil] the deleted value, or result of block if key not found
    #
    # @example Delete an attribute
    #   struct = LazyStruct.new(name: "John", age: 30)
    #   struct.delete!(:age) #=> 30
    #   struct.age #=> nil
    #
    # @example Delete with default block
    #   struct.delete!(:missing) { "not found" } #=> "not found"
    def delete!(key, &)
      table.delete(symbolized_key(key), &)
    end
    alias delete_field! delete!

    # Checks equality with another object.
    #
    # @param other [Object] the object to compare against
    #
    # @return [Boolean] true if other is a LazyStruct with identical attributes
    #
    # @example Compare structs
    #   struct1 = LazyStruct.new(name: "John")
    #   struct2 = LazyStruct.new(name: "John")
    #   struct1.eql?(struct2) #=> true
    def eql?(other)
      other.is_a?(self.class) && (to_h == other.to_h)
    end
    alias == eql?

    # Extracts nested values using key path traversal.
    #
    # @param key [Symbol, String] the initial key to look up
    # @param keys [Array<Symbol, String>] additional keys for nested traversal
    #
    # @return [Object, nil] the nested value, or nil if any key in the path is missing
    #
    # @example Dig into nested structure
    #   struct = LazyStruct.new(user: { profile: { name: "John" } })
    #   struct.dig(:user, :profile, :name) #=> "John"
    #   struct.dig(:user, :missing, :name) #=> nil
    def dig(key, *keys)
      table.dig(symbolized_key(key), *keys)
    end

    # Iterates over each key-value pair in the struct.
    #
    # @param block [Proc] the block to execute for each key-value pair
    #
    # @return [Enumerator, LazyStruct] an enumerator if no block given, self otherwise
    #
    # @example Iterate over pairs
    #   struct = LazyStruct.new(name: "John", age: 30)
    #   struct.each_pair { |key, value| puts "#{key}: #{value}" }
    #   # Output: name: John
    #   #         age: 30
    def each_pair(&)
      table.each_pair(&)
    end

    # Converts the struct to a hash representation.
    #
    # @param block [Proc] optional block for transforming key-value pairs
    #
    # @return [Hash] a hash containing all the struct's attributes
    #
    # @example Convert to hash
    #   struct = LazyStruct.new(name: "John", age: 30)
    #   struct.to_h #=> { name: "John", age: 30 }
    #
    # @example Convert with transformation
    #   struct.to_h { |k, v| [k.to_s, v.to_s] } #=> { "name" => "John", "age" => "30" }
    def to_h(&)
      table.to_h(&)
    end

    # Returns a string representation of the struct for debugging.
    #
    # @return [String] a formatted string showing the class name and attributes
    #
    # @example Inspect struct
    #   struct = LazyStruct.new(name: "John", age: 30)
    #   struct.inspect #=> "#<CMDx::LazyStruct :name=\"John\" :age=30>"
    def inspect
      "#<#{self.class.name}#{table.map { |key, value| ":#{key}=#{value.inspect}" }.join(' ')}>"
    end
    alias to_s inspect

    private

    # Returns the internal hash table storing the struct's attributes.
    #
    # @return [Hash] the internal attribute storage
    def table
      @table ||= {}
    end

    # Handles dynamic method calls for attribute access and assignment.
    #
    # @param method_name [Symbol] the method name being called
    # @param args [Array] arguments passed to the method
    # @param _kwargs [Hash] keyword arguments (unused)
    # @param block [Proc] block passed to the method (unused)
    #
    # @return [Object, nil] the attribute value for getters, or the assigned value for setters
    #
    # @example Dynamic attribute access
    #   struct = LazyStruct.new(name: "John")
    #   struct.name #=> "John"
    #   struct.age = 30 #=> 30
    def method_missing(method_name, *args, **_kwargs, &)
      table.fetch(symbolized_key(method_name)) do
        store!(method_name[0..-2], args.first) if method_name.end_with?("=")
      end
    end

    # Checks if the struct responds to a method name.
    #
    # @param method_name [Symbol] the method name to check
    # @param include_private [Boolean] whether to include private methods
    #
    # @return [Boolean] true if the struct has the attribute or responds to the method
    def respond_to_missing?(method_name, include_private = false)
      table.key?(symbolized_key(method_name)) || super
    end

    # Converts a key to a symbol for consistent internal storage.
    #
    # @param key [Symbol, String, Object] the key to convert
    #
    # @return [Symbol] the symbolized key
    #
    # @raise [TypeError] if the key cannot be converted to a symbol
    def symbolized_key(key)
      key.to_sym
    rescue NoMethodError
      raise TypeError, "#{key} is not a symbol nor a string"
    end

  end
end
