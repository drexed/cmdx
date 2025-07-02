# frozen_string_literal: true

module CMDx
  ##
  # LazyStruct provides a flexible, hash-like data structure with dynamic method access
  # and lazy attribute definition. It serves as the foundation for CMDx's Context system,
  # allowing for dynamic parameter access and manipulation with both hash-style and
  # method-style syntax.
  #
  # LazyStruct combines the flexibility of a Hash with the convenience of method access,
  # automatically creating getter and setter methods for any key-value pairs stored within it.
  # All keys are normalized to symbols for consistent access patterns.
  #
  #
  # @example Basic usage
  #   struct = LazyStruct.new(name: "John", age: 30)
  #   struct.name        #=> "John"
  #   struct.age         #=> 30
  #   struct[:name]      #=> "John"
  #   struct["age"]      #=> 30
  #
  # @example Dynamic attribute assignment
  #   struct = LazyStruct.new
  #   struct.email = "john@example.com"
  #   struct[:phone] = "555-1234"
  #   struct["address"] = "123 Main St"
  #
  #   struct.email       #=> "john@example.com"
  #   struct.phone       #=> "555-1234"
  #   struct.address     #=> "123 Main St"
  #
  # @example Hash-like operations
  #   struct = LazyStruct.new(name: "John")
  #   struct.merge!(age: 30, city: "NYC")
  #   struct.delete!(:city)
  #   struct.to_h        #=> {:name => "John", :age => 30}
  #
  # @example Nested data access
  #   struct = LazyStruct.new(user: {profile: {name: "John"}})
  #   struct.dig(:user, :profile, :name)  #=> "John"
  #
  # @example Usage in CMDx Context
  #   class ProcessUserTask < CMDx::Task
  #     required :user_id, type: :integer
  #
  #     def call
  #       context.user = User.find(user_id)
  #       context.processed_at = Time.now
  #       context.result_data = {status: "complete"}
  #     end
  #   end
  #
  #   result = ProcessUserTask.call(user_id: 123)
  #   result.context.user         #=> <User id: 123>
  #   result.context.processed_at #=> 2023-01-01 12:00:00 UTC
  #
  # @see Context Context class that inherits from LazyStruct
  # @see Configuration Configuration class that uses LazyStruct
  # @since 1.0.0
  class LazyStruct

    ##
    # Initializes a new LazyStruct with the given data.
    # The input must respond to `to_h` for hash conversion.
    #
    # @param args [Hash, #to_h] initial data for the struct
    # @raise [ArgumentError] if args doesn't respond to `to_h`
    #
    # @example With hash
    #   struct = LazyStruct.new(name: "John", age: 30)
    #
    # @example With hash-like object
    #   params = ActionController::Parameters.new(name: "John")
    #   struct = LazyStruct.new(params)
    #
    # @example Empty initialization
    #   struct = LazyStruct.new
    #   struct.name = "John"  # Dynamic assignment
    def initialize(args = {})
      unless args.respond_to?(:to_h)
        raise ArgumentError,
              "must be respond to `to_h`"
      end

      @table = args.to_h.transform_keys { |k| symbolized_key(k) }
    end

    ##
    # Retrieves a value by key using hash-style access.
    # Keys are automatically converted to symbols.
    #
    # @param key [Symbol, String] the key to retrieve
    # @return [Object, nil] the stored value or nil if not found
    #
    # @example
    #   struct[:name]    #=> "John"
    #   struct["name"]   #=> "John"
    #   struct[:missing] #=> nil
    def [](key)
      table[symbolized_key(key)]
    end

    ##
    # Retrieves a value by key with error handling and default support.
    # Similar to Hash#fetch, raises KeyError if key not found and no default given.
    #
    # @param key [Symbol, String] the key to retrieve
    # @param args [Array] default value if key not found
    # @return [Object] the stored value or default
    # @raise [KeyError] if key not found and no default provided
    #
    # @example With existing key
    #   struct.fetch!(:name)  #=> "John"
    #
    # @example With default value
    #   struct.fetch!(:missing, "default")  #=> "default"
    #
    # @example With block default
    #   struct.fetch!(:missing) { "computed default" }  #=> "computed default"
    #
    # @example Key not found
    #   struct.fetch!(:missing)  #=> raises KeyError
    def fetch!(key, ...)
      table.fetch(symbolized_key(key), ...)
    end

    ##
    # Stores a value by key, converting the key to a symbol.
    #
    # @param key [Symbol, String] the key to store under
    # @param value [Object] the value to store
    # @return [Object] the stored value
    #
    # @example
    #   struct.store!(:name, "John")
    #   struct.store!("age", 30)
    #   struct.name  #=> "John"
    #   struct.age   #=> 30
    def store!(key, value)
      table[symbolized_key(key)] = value
    end
    alias []= store!

    ##
    # Merges another hash-like object into this struct.
    # All keys from the source are converted to symbols.
    #
    # @param args [Hash, #to_h] data to merge into this struct
    # @return [LazyStruct] self for method chaining
    #
    # @example
    #   struct = LazyStruct.new(name: "John")
    #   struct.merge!(age: 30, city: "NYC")
    #   struct.to_h  #=> {:name => "John", :age => 30, :city => "NYC"}
    def merge!(args = {})
      args.to_h.each { |key, value| store!(key, value) }
      self
    end

    ##
    # Deletes a key-value pair from the struct.
    #
    # @param key [Symbol, String] the key to delete
    # @param block [Proc] optional block to execute if key not found
    # @return [Object, nil] the deleted value or result of block
    #
    # @example
    #   struct.delete!(:name)     #=> "John"
    #   struct.delete!(:missing)  #=> nil
    #   struct.delete!(:missing) { "not found" }  #=> "not found"
    def delete!(key, &)
      table.delete(symbolized_key(key), &)
    end
    alias delete_field! delete!

    ##
    # Compares this struct with another for equality.
    # Two LazyStructs are equal if they have the same class and hash representation.
    #
    # @param other [Object] object to compare with
    # @return [Boolean] true if structs are equal
    #
    # @example
    #   struct1 = LazyStruct.new(name: "John")
    #   struct2 = LazyStruct.new(name: "John")
    #   struct1 == struct2  #=> true
    #   struct1.eql?(struct2)  #=> true
    def eql?(other)
      other.is_a?(self.class) && (to_h == other.to_h)
    end
    alias == eql?

    ##
    # Retrieves nested values using a sequence of keys.
    # Similar to Hash#dig, safely navigates nested structures.
    #
    # @param key [Symbol, String] the first key to access
    # @param keys [Array<Symbol, String>] additional keys for nested access
    # @return [Object, nil] the nested value or nil if path doesn't exist
    # @raise [TypeError] if key cannot be converted to symbol
    #
    # @example
    #   struct = LazyStruct.new(user: {profile: {name: "John"}})
    #   struct.dig(:user, :profile, :name)  #=> "John"
    #   struct.dig(:user, :missing, :name)  #=> nil
    def dig(key, *keys)
      table.dig(symbolized_key(key), *keys)
    end

    ##
    # Iterates over each key-value pair in the struct.
    #
    # @yieldparam key [Symbol] the key
    # @yieldparam value [Object] the value
    # @return [LazyStruct] self if block given, Enumerator otherwise
    #
    # @example
    #   struct.each_pair { |key, value| puts "#{key}: #{value}" }
    def each_pair(&)
      table.each_pair(&)
    end

    ##
    # Converts the struct to a hash representation.
    #
    # @param block [Proc] optional block for hash transformation
    # @return [Hash] hash representation with symbol keys
    #
    # @example
    #   struct = LazyStruct.new(name: "John", age: 30)
    #   struct.to_h  #=> {:name => "John", :age => 30}
    def to_h(&)
      table.to_h(&)
    end

    ##
    # Returns a string representation of the struct showing all key-value pairs.
    #
    # @return [String] formatted string representation
    #
    # @example
    #   struct = LazyStruct.new(name: "John", age: 30)
    #   struct.inspect  #=> '#<CMDx::LazyStruct:name="John" :age=30>'
    def inspect
      "#<#{self.class.name}#{table.map { |key, value| ":#{key}=#{value.inspect}" }.join(' ')}>"
    end
    alias to_s inspect

    private

    def table
      @table ||= {}
    end

    ##
    # Handles dynamic method calls for attribute access and assignment.
    # Getter methods return the stored value, setter methods (ending with =) store values.
    #
    # @param method_name [Symbol] the method name being called
    # @param args [Array] arguments passed to the method
    # @return [Object] the stored value for getters, the assigned value for setters
    #
    # @example Getter methods
    #   struct.name        # Calls method_missing(:name)
    #   struct.undefined   # Calls method_missing(:undefined) => nil
    #
    # @example Setter methods
    #   struct.name = "John"  # Calls method_missing(:name=, "John")
    #
    # @api private
    def method_missing(method_name, *args, **_kwargs, &)
      table.fetch(symbolized_key(method_name)) do
        store!(method_name[0..-2], args.first) if method_name.end_with?("=")
      end
    end

    ##
    # Determines if the struct responds to a given method name.
    # Returns true for any key in the internal table or standard methods.
    #
    # @param method_name [Symbol] the method name to check
    # @param include_private [Boolean] whether to include private methods
    # @return [Boolean] true if the struct responds to the method
    #
    # @example
    #   struct = LazyStruct.new(name: "John")
    #   struct.respond_to?(:name)     #=> true
    #   struct.respond_to?(:missing)  #=> false
    #   struct.respond_to?(:to_h)     #=> true
    #
    # @api private
    def respond_to_missing?(method_name, include_private = false)
      table.key?(symbolized_key(method_name)) || super
    end

    ##
    # Converts a key to a symbol for consistent internal storage.
    # This method normalizes all keys to symbols regardless of their input type,
    # ensuring consistent access patterns throughout the LazyStruct.
    #
    # @param key [Object] the key to convert to a symbol
    # @return [Symbol] the key converted to a symbol
    # @raise [TypeError] if the key cannot be converted to a symbol (doesn't respond to `to_sym`)
    #
    # @example Valid key conversion
    #   symbolized_key("name")    #=> :name
    #   symbolized_key(:name)     #=> :name
    #   symbolized_key("123")     #=> :"123"
    #
    # @example Invalid key conversion
    #   symbolized_key(Object.new)  #=> raises TypeError
    #   symbolized_key(123)         #=> raises TypeError
    #
    # @api private
    def symbolized_key(key)
      key.to_sym
    rescue NoMethodError
      raise TypeError, "#{key} is not a symbol nor a string"
    end

  end
end
