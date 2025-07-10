# frozen_string_literal: true

module CMDx
  module CoreExt
    # Extensions for Ruby's Hash class that provide flexible key access and querying.
    # These extensions are automatically included in all hashes when CMDx is loaded, providing
    # seamless symbol/string key interoperability and enhanced key existence checking.
    #
    # @since 1.0.0
    module HashExtensions

      # Fetches a value from the hash with flexible key matching.
      # Tries the exact key first, then attempts symbol/string conversion if not found.
      #
      # @param key [Symbol, String, Object] the key to fetch from the hash
      #
      # @return [Object, nil] the value associated with the key, or nil if not found
      #
      # @example Fetch with symbol key
      #   hash = { name: "John", "age" => 30 }
      #   hash.cmdx_fetch(:name) # => "John"
      #   hash.cmdx_fetch(:age)  # => 30
      #
      # @example Fetch with string key
      #   hash = { name: "John", "age" => 30 }
      #   hash.cmdx_fetch("name") # => "John"
      #   hash.cmdx_fetch("age")  # => 30
      def cmdx_fetch(key)
        case key
        when Symbol then fetch(key) { self[key.to_s] }
        when String then fetch(key) { self[key.to_sym] }
        else self[key]
        end
      end

      # Checks if a key exists in the hash with flexible key matching.
      # Tries the exact key first, then attempts symbol/string conversion.
      #
      # @param key [Symbol, String, Object] the key to check for existence
      #
      # @return [Boolean] true if the key exists (in any form), false otherwise
      #
      # @example Check key existence
      #   hash = { name: "John", "age" => 30 }
      #   hash.cmdx_key?(:name)   # => true
      #   hash.cmdx_key?("name")  # => true
      #   hash.cmdx_key?(:age)    # => true
      #   hash.cmdx_key?("age")   # => true
      #   hash.cmdx_key?(:missing) # => false
      def cmdx_key?(key)
        key?(key) || key?(
          case key
          when Symbol then key.to_s
          when String then key.to_sym
          end
        )
      rescue NoMethodError
        false
      end

      # Checks if the hash responds to a method or contains a key.
      # Combines method existence checking with flexible key existence checking.
      #
      # @param key [Symbol, String] the method name or key to check
      # @param include_private [Boolean] whether to include private methods in the check
      #
      # @return [Boolean] true if the hash responds to the method or contains the key
      #
      # @example Check method or key response
      #   hash = { name: "John", "age" => 30 }
      #   hash.cmdx_respond_to?(:keys)     # => true (method exists)
      #   hash.cmdx_respond_to?(:name)     # => true (key exists)
      #   hash.cmdx_respond_to?("age")     # => true (key exists)
      #   hash.cmdx_respond_to?(:missing)  # => false
      def cmdx_respond_to?(key, include_private = false)
        respond_to?(key.to_sym, include_private) || cmdx_key?(key)
      rescue NoMethodError
        cmdx_key?(key)
      end

    end
  end
end

Hash.include(CMDx::CoreExt::HashExtensions)
