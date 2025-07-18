# frozen_string_literal: true

module CMDx
  # Container for collecting and managing validation and execution errors by attribute.
  # Provides a comprehensive API for adding, querying, and formatting error messages
  # with support for multiple errors per attribute and various output formats.
  class Errors

    cmdx_attr_delegator :clear, :delete, :empty?, :key?, :keys, :size, :values,
                        to: :errors

    # @return [Hash] internal hash storing error messages by attribute
    attr_reader :errors

    # @return [Array<Symbol>] list of attributes that have errors
    alias attribute_names keys

    # @return [Boolean] true if no errors are present
    alias blank? empty?

    # @return [Boolean] true if no errors are present
    alias valid? empty?

    # Alias for {#key?}. Checks if an attribute has error messages.
    alias has_key? key?

    # Alias for {#key?}. Checks if an attribute has error messages.
    alias include? key?

    # Creates a new empty errors collection.
    #
    # @return [Errors] a new errors instance with empty internal hash
    #
    # @example Create new errors collection
    #   errors = CMDx::Errors.new
    #   errors.empty? # => true
    def initialize
      @errors = {}
    end

    # Adds an error message to the specified attribute. Automatically handles
    # array initialization and prevents duplicate messages for the same attribute.
    #
    # @param key [Symbol, String] the attribute name to associate the error with
    # @param value [String, Object] the error message or error object to add
    #
    # @return [Array] the updated array of error messages for the attribute
    #
    # @example Add error to attribute
    #   errors.add(:name, "can't be blank")
    #   errors.add(:name, "is too short")
    #   errors.messages_for(:name) # => ["can't be blank", "is too short"]
    #
    # @example Prevent duplicate errors
    #   errors.add(:email, "is invalid")
    #   errors.add(:email, "is invalid")
    #   errors.messages_for(:email) # => ["is invalid"]
    def add(key, value)
      errors[key] ||= []
      errors[key] << value
      errors[key].uniq!
    end
    alias []= add

    # Checks if a specific error message has been added to an attribute.
    #
    # @param key [Symbol, String] the attribute name to check
    # @param val [String, Object] the error message to look for
    #
    # @return [Boolean] true if the error exists for the attribute, false otherwise
    #
    # @example Check for specific error
    #   errors.add(:name, "can't be blank")
    #   errors.added?(:name, "can't be blank") # => true
    #   errors.added?(:name, "is invalid") # => false
    #
    # @example Check non-existent attribute
    #   errors.added?(:nonexistent, "error") # => false
    def added?(key, val)
      return false unless key?(key)

      errors[key].include?(val)
    end
    alias of_kind? added?

    # Iterates over each error, yielding the attribute name and error message.
    #
    # @yield [key, value] gives the attribute name and error message for each error
    # @yieldparam key [Symbol, String] the attribute name
    # @yieldparam value [String, Object] the error message
    #
    # @return [Hash] the errors hash when no block given
    #
    # @example Iterate over all errors
    #   errors.add(:name, "can't be blank")
    #   errors.add(:email, "is invalid")
    #   errors.each { |attr, msg| puts "#{attr}: #{msg}" }
    #   # Output:
    #   # name: can't be blank
    #   # email: is invalid
    def each
      errors.each_key do |key|
        errors[key].each { |val| yield(key, val) }
      end
    end

    # Formats an error message by combining the attribute name and error value.
    #
    # @param key [Symbol, String] the attribute name
    # @param value [String, Object] the error message
    #
    # @return [String] the formatted full error message
    #
    # @example Format error message
    #   errors.full_message(:name, "can't be blank") # => "name can't be blank"
    #   errors.full_message(:email, "is invalid") # => "email is invalid"
    def full_message(key, value)
      "#{key} #{value}"
    end

    # Returns all error messages formatted with their attribute names.
    #
    # @return [Array<String>] array of formatted error messages
    #
    # @example Get all formatted messages
    #   errors.add(:name, "can't be blank")
    #   errors.add(:email, "is invalid")
    #   errors.full_messages # => ["name can't be blank", "email is invalid"]
    #
    # @example Empty errors collection
    #   errors.full_messages # => []
    def full_messages
      errors.each_with_object([]) do |(key, arr), memo|
        arr.each { |val| memo << full_message(key, val) }
      end
    end
    alias to_a full_messages

    # Returns formatted error messages for a specific attribute.
    #
    # @param key [Symbol, String] the attribute name to get messages for
    #
    # @return [Array<String>] array of formatted error messages for the attribute
    #
    # @example Get messages for existing attribute
    #   errors.add(:name, "can't be blank")
    #   errors.add(:name, "is too short")
    #   errors.full_messages_for(:name) # => ["name can't be blank", "name is too short"]
    #
    # @example Get messages for non-existent attribute
    #   errors.full_messages_for(:nonexistent) # => []
    def full_messages_for(key)
      return [] unless key?(key)

      errors[key].map { |val| full_message(key, val) }
    end

    # Checks if the errors collection contains any validation errors.
    #
    # @return [Boolean] true if there are any errors present, false otherwise
    #
    # @example Check invalid state
    #   errors.add(:name, "can't be blank")
    #   errors.invalid? # => true
    #
    # @example Check valid state
    #   errors.invalid? # => false
    def invalid?
      !valid?
    end

    # Transforms each error using the provided block and returns results as an array.
    #
    # @yield [key, value] gives the attribute name and error message for transformation
    # @yieldparam key [Symbol, String] the attribute name
    # @yieldparam value [String, Object] the error message
    # @yieldreturn [Object] the transformed value to include in result array
    #
    # @return [Array] array of transformed error values
    #
    # @example Transform errors to uppercase messages
    #   errors.add(:name, "can't be blank")
    #   errors.add(:email, "is invalid")
    #   errors.map { |attr, msg| msg.upcase } # => ["CAN'T BE BLANK", "IS INVALID"]
    #
    # @example Create custom error objects
    #   errors.map { |attr, msg| { attribute: attr, message: msg } }
    #   # => [{ attribute: :name, message: "can't be blank" }]
    def map
      errors.each_with_object([]) do |(key, _arr), memo|
        memo.concat(errors[key].map { |val| yield(key, val) })
      end
    end

    # Merges another errors hash into this collection, combining arrays for duplicate keys.
    #
    # @param hash [Hash] hash of errors to merge, with attribute keys and message arrays as values
    #
    # @return [Hash] the updated internal errors hash
    #
    # @example Merge additional errors
    #   errors.add(:name, "can't be blank")
    #   other_errors = { email: ["is invalid"], name: ["is too short"] }
    #   errors.merge!(other_errors)
    #   errors.messages_for(:name) # => ["can't be blank", "is too short"]
    #   errors.messages_for(:email) # => ["is invalid"]
    #
    # @example Merge with duplicate prevention
    #   errors.add(:name, "can't be blank")
    #   duplicate_errors = { name: ["can't be blank", "is required"] }
    #   errors.merge!(duplicate_errors)
    #   errors.messages_for(:name) # => ["can't be blank", "is required"]
    def merge!(hash)
      errors.merge!(hash) do |_, arr1, arr2|
        arr3 = arr1 + arr2
        arr3.uniq!
        arr3
      end
    end

    # Returns the raw error messages for a specific attribute without formatting.
    #
    # @param key [Symbol, String] the attribute name to get messages for
    #
    # @return [Array] array of raw error messages for the attribute
    #
    # @example Get raw messages for existing attribute
    #   errors.add(:name, "can't be blank")
    #   errors.add(:name, "is too short")
    #   errors.messages_for(:name) # => ["can't be blank", "is too short"]
    #
    # @example Get messages for non-existent attribute
    #   errors.messages_for(:nonexistent) # => []
    def messages_for(key)
      return [] unless key?(key)

      errors[key]
    end
    alias [] messages_for

    # Checks if the errors collection contains any validation errors.
    #
    # @return [Boolean] true if there are any errors present, false otherwise
    #
    # @example Check for errors presence
    #   errors.add(:name, "can't be blank")
    #   errors.present? # => true
    #
    # @example Check empty collection
    #   errors.present? # => false
    def present?
      !blank?
    end

    # Converts the errors collection to a hash format, optionally with full formatted messages.
    #
    # @param full_messages [Boolean] whether to format messages with attribute names
    #
    # @return [Hash] hash representation of errors
    # @option return [Array<String>] attribute_name array of error messages (raw or formatted)
    #
    # @example Get raw errors hash
    #   errors.add(:name, "can't be blank")
    #   errors.add(:email, "is invalid")
    #   errors.to_hash # => { :name => ["can't be blank"], :email => ["is invalid"] }
    #
    # @example Get formatted errors hash
    #   errors.to_hash(true) # => { :name => ["name can't be blank"], :email => ["email is invalid"] }
    #
    # @example Empty errors collection
    #   errors.to_hash # => {}
    def to_hash(full_messages = false)
      return errors unless full_messages

      errors.each_with_object({}) do |(key, arr), memo|
        memo[key] = arr.map { |val| full_message(key, val) }
      end
    end
    alias messages to_hash
    alias group_by_attribute to_hash
    alias as_json to_hash

  end
end
