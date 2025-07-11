# frozen_string_literal: true

module CMDx
  # Hash-like data structure with dynamic attribute access and automatic key normalization.
  #
  # LazyStruct provides a flexible data container that combines hash-like access patterns
  # with dynamic method calls. All keys are automatically converted to symbols for
  # consistent access, and the structure supports both bracket notation and method-style
  # attribute access through method_missing.
  class LazyStruct

    # Creates a new LazyStruct instance from the provided arguments.
    #
    # @param args [Hash, #to_h] initial data for the structure, must respond to to_h
    #
    # @return [LazyStruct] a new LazyStruct instance
    #
    # @raise [ArgumentError] if args doesn't respond to to_h
    #
    # @example Create with hash data
    #   struct = LazyStruct.new(name: "John", age: 30)
    #   struct.name # => "John"
    #
    # @example Create with hash-like object
    #   struct = LazyStruct.new(OpenStruct.new(status: "active"))
    #   struct.status # => "active"
    def initialize(args = {})
      unless args.respond_to?(:to_h)
        raise ArgumentError,
              "must be respond to `to_h`"
      end

      @table = args.to_h.transform_keys { |k| symbolized_key(k) }
    end

    # Retrieves the value for the specified key.
    #
    # @param key [Symbol, String] the key to retrieve
    #
    # @return [Object, nil] the value associated with the key, or nil if not found
    #
    # @example Access existing key
    #   struct = LazyStruct.new(name: "John")
    #   struct[:name] # => "John"
    #   struct["name"] # => "John"
    def [](key)
      table[symbolized_key(key)]
    end

    # Fetches the value for the specified key with optional default handling.
    #
    # @param key [Symbol, String] the key to fetch
    # @param args [Array] optional default value or block arguments
    #
    # @return [Object] the value associated with the key, or default if not found
    #
    # @raise [KeyError] if key is not found and no default is provided
    #
    # @example Fetch with default value
    #   struct = LazyStruct.new(name: "John")
    #   struct.fetch!(:name) # => "John"
    #   struct.fetch!(:missing, "default") # => "default"
    #
    # @example Fetch with block
    #   struct.fetch!(:missing) { "computed default" } # => "computed default"
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
    #   struct.store!(:name, "John") # => "John"
    #   struct[:name] # => "John"
    def store!(key, value)
      table[symbolized_key(key)] = value
    end
    alias []= store!

    # Merges the provided arguments into the current structure.
    #
    # @param args [Hash, #to_h] the data to merge, must respond to to_h
    #
    # @return [LazyStruct] returns self for method chaining
    #
    # @example Merge additional data
    #   struct = LazyStruct.new(name: "John")
    #   struct.merge!(age: 30, city: "NYC")
    #   struct.age # => 30
    def merge!(args = {})
      args.to_h.each { |key, value| store!(symbolized_key(key), value) }
      self
    end

    # Deletes the specified key from the structure.
    #
    # @param key [Symbol, String] the key to delete
    # @param block [Proc] optional block to execute if key is not found
    #
    # @return [Object, nil] the deleted value, or result of block if key not found
    #
    # @example Delete a key
    #   struct = LazyStruct.new(name: "John", age: 30)
    #   struct.delete!(:age) # => 30
    #   struct.age # => nil
    def delete!(key, &)
      table.delete(symbolized_key(key), &)
    end
    alias delete_field! delete!

    # Checks equality with another LazyStruct instance.
    #
    # @param other [Object] the object to compare with
    #
    # @return [Boolean] true if both objects are LazyStruct instances with the same data
    #
    # @example Compare structures
    #   struct1 = LazyStruct.new(name: "John")
    #   struct2 = LazyStruct.new(name: "John")
    #   struct1.eql?(struct2) # => true
    def eql?(other)
      other.is_a?(self.class) && (to_h == other.to_h)
    end
    alias == eql?

    # Extracts nested values using the specified key path.
    #
    # @param key [Symbol, String] the first key in the path
    # @param keys [Array] additional keys for nested access
    #
    # @return [Object, nil] the value at the specified path, or nil if not found
    #
    # @example Dig into nested structure
    #   struct = LazyStruct.new(user: { profile: { name: "John" } })
    #   struct.dig(:user, :profile, :name) # => "John"
    def dig(key, *keys)
      table.dig(symbolized_key(key), *keys)
    end

    # Iterates over each key-value pair in the structure.
    #
    # @param block [Proc] the block to execute for each pair
    #
    # @return [LazyStruct] returns self if block given, otherwise returns enumerator
    #
    # @example Iterate over pairs
    #   struct = LazyStruct.new(name: "John", age: 30)
    #   struct.each_pair { |key, value| puts "#{key}: #{value}" }
    #   # Output: name: John, age: 30
    def each_pair(&)
      table.each_pair(&)
    end

    # Converts the structure to a hash representation.
    #
    # @param block [Proc] optional block for hash transformation
    #
    # @return [Hash] hash representation of the structure
    #
    # @example Convert to hash
    #   struct = LazyStruct.new(name: "John", age: 30)
    #   struct.to_h # => {:name=>"John", :age=>30}
    def to_h(&)
      table.to_h(&)
    end

    # Returns a string representation of the structure.
    #
    # @return [String] formatted string showing class name and key-value pairs
    #
    # @example Inspect structure
    #   struct = LazyStruct.new(name: "John", age: 30)
    #   struct.inspect # => "#<CMDx::LazyStruct :name=\"John\" :age=30>"
    def inspect
      "#<#{self.class.name}#{table.map { |key, value| ":#{key}=#{value.inspect}" }.join(' ')}>"
    end
    alias to_s inspect

    private

    # Returns the internal hash table, initializing it if needed.
    #
    # @return [Hash] the internal hash storage
    def table
      @table ||= {}
    end

    # Provides dynamic method access to stored values and assignment.
    #
    # @param method_name [Symbol] the method name being called
    # @param args [Array] method arguments
    # @param _kwargs [Hash] keyword arguments (unused)
    # @param block [Proc] optional block (unused)
    #
    # @return [Object] the value for the method name, or result of assignment
    #
    # @example Dynamic method access
    #   struct = LazyStruct.new(name: "John")
    #   struct.name # => "John"
    #   struct.age = 30
    #   struct.age # => 30
    def method_missing(method_name, *args, **_kwargs, &)
      table.fetch(symbolized_key(method_name)) do
        store!(method_name[0..-2], args.first) if method_name.end_with?("=")
      end
    end

    # Checks if the structure responds to the specified method name.
    #
    # @param method_name [Symbol] the method name to check
    # @param include_private [Boolean] whether to include private methods
    #
    # @return [Boolean] true if method is available or key exists in structure
    def respond_to_missing?(method_name, include_private = false)
      table.key?(symbolized_key(method_name)) || super
    end

    # Converts a key to a symbol for consistent internal storage.
    #
    # @param key [Object] the key to convert to symbol
    #
    # @return [Symbol] the symbolized key
    #
    # @raise [TypeError] if key cannot be converted to symbol
    def symbolized_key(key)
      key.to_sym
    rescue NoMethodError
      raise TypeError, "#{key} is not a symbol nor a string"
    end

  end
end
