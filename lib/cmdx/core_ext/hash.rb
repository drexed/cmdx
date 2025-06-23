# frozen_string_literal: true

module CMDx
  module CoreExt
    # Extensions to Hash that provide CMDx-specific key access methods.
    #
    # HashExtensions adds flexible key access that works with both
    # string and symbol keys interchangeably. These methods are prefixed
    # with `__cmdx_` to avoid conflicts with existing Hash methods.
    #
    # @example Flexible key access
    #   hash = {name: "John", "age" => 30}
    #   hash.__cmdx_fetch(:name)      # => "John" (symbol key)
    #   hash.__cmdx_fetch("name")     # => "John" (tries symbol fallback)
    #   hash.__cmdx_fetch(:age)       # => 30 (string fallback)
    #
    # @example Key checking
    #   hash.__cmdx_key?(:name)       # => true (checks both symbol and string)
    #   hash.__cmdx_key?("age")       # => true (checks both string and symbol)
    #
    # @example Method response checking
    #   hash.__cmdx_respond_to?(:name)   # => true (considers key as method)
    #
    # @see Context Context objects that use hash extensions
    # @see LazyStruct Structs that leverage hash-like behavior
    module HashExtensions

      # Fetch a value with automatic symbol/string key conversion.
      #
      # This method provides flexible key access by trying both the original
      # key and its converted form (symbol to string or string to symbol).
      # This is particularly useful for parameter hashes that might use
      # either format.
      #
      # @param key [Symbol, String, Object] key to fetch
      # @return [Object] value for the key or its converted equivalent
      #
      # @example Symbol to string conversion
      #   hash = {"name" => "John"}
      #   hash.__cmdx_fetch(:name)        # => "John" (tries :name, then "name")
      #
      # @example String to symbol conversion
      #   hash = {name: "John"}
      #   hash.__cmdx_fetch("name")       # => "John" (tries "name", then :name)
      #
      # @example Direct key access
      #   hash = {id: 123}
      #   hash.__cmdx_fetch(:id)          # => 123 (direct match)
      def __cmdx_fetch(key)
        case key
        when Symbol then fetch(key) { self[key.to_s] }
        when String then fetch(key) { self[key.to_sym] }
        else self[key]
        end
      end

      # Check if a key exists with automatic symbol/string conversion.
      #
      # This method checks for key existence by trying both the original
      # key and its converted form. Returns true if either variant exists.
      #
      # @param key [Symbol, String, Object] key to check
      # @return [Boolean] true if key exists in either format
      #
      # @example Symbol/string checking
      #   hash = {name: "John", "age" => 30}
      #   hash.__cmdx_key?(:name)         # => true
      #   hash.__cmdx_key?("name")        # => true (checks :name fallback)
      #   hash.__cmdx_key?(:age)          # => true (checks "age" fallback)
      #   hash.__cmdx_key?(:missing)      # => false
      def __cmdx_key?(key)
        key?(key) || key?(
          case key
          when Symbol then key.to_s
          when String then key.to_sym
          end
        )
      rescue NoMethodError
        false
      end

      # Check if hash responds to a method or contains a key.
      #
      # This method extends respond_to? behavior to also check if the
      # hash contains a key that matches the method name. This enables
      # hash keys to be treated as virtual methods.
      #
      # @param key [Symbol, String] method name to check
      # @param include_private [Boolean] whether to include private methods
      # @return [Boolean] true if responds to method or contains key
      #
      # @example Method response checking
      #   hash = {name: "John"}
      #   hash.__cmdx_respond_to?(:name)     # => true (has key :name)
      #   hash.__cmdx_respond_to?(:keys)     # => true (real Hash method)
      #   hash.__cmdx_respond_to?(:missing)  # => false
      def __cmdx_respond_to?(key, include_private = false)
        respond_to?(key.to_sym, include_private) || __cmdx_key?(key)
      rescue NoMethodError
        __cmdx_key?(key)
      end

    end
  end
end

# Extend all hashes with CMDx utility methods
Hash.include(CMDx::CoreExt::HashExtensions)
