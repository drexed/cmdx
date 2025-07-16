# frozen_string_literal: true

module CMDx
  # Error collection and validation system for CMDx tasks.
  #
  # This class manages error messages associated with specific attributes,
  # providing a flexible API for adding, querying, and formatting validation
  # errors. It supports both individual error messages and collections of
  # errors per attribute, with various convenience methods for error handling
  # and display.
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

    # Creates a new error collection with an empty internal hash.
    #
    # @return [Errors] the newly created error collection
    #
    # @example Create a new error collection
    #   errors = CMDx::Errors.new
    #   errors.empty? # => true
    def initialize
      @errors = {}
    end

    # Adds an error message to the specified attribute.
    #
    # If the attribute already has errors, the new message is appended to the
    # existing array. Duplicate messages are automatically removed to ensure
    # each error message appears only once per attribute.
    #
    # @param key [Symbol, String] the attribute name to associate the error with
    # @param value [String] the error message to add
    #
    # @return [Array<String>] the array of error messages for the attribute
    #
    # @example Add an error to an attribute
    #   errors = CMDx::Errors.new
    #   errors.add(:name, "is required")
    #   errors[:name] # => ["is required"]
    #
    # @example Add multiple errors to the same attribute
    #   errors.add(:email, "is required")
    #   errors.add(:email, "must be valid")
    #   errors[:email] # => ["is required", "must be valid"]
    #
    # @example Duplicate errors are automatically removed
    #   errors.add(:age, "must be positive")
    #   errors.add(:age, "must be positive")
    #   errors[:age] # => ["must be positive"]
    def add(key, value)
      errors[key] ||= []
      errors[key] << value
      errors[key].uniq!
    end
    alias []= add

    # Checks if a specific error message has been added to an attribute.
    #
    # @param key [Symbol, String] the attribute name to check
    # @param val [String] the error message to look for
    #
    # @return [Boolean] true if the specific error message exists for the attribute
    #
    # @example Check if a specific error exists
    #   errors = CMDx::Errors.new
    #   errors.add(:name, "is required")
    #   errors.added?(:name, "is required") # => true
    #   errors.added?(:name, "is invalid") # => false
    #
    # @example Check error on attribute without errors
    #   errors.added?(:missing, "any error") # => false
    def added?(key, val)
      return false unless key?(key)

      errors[key].include?(val)
    end
    alias of_kind? added?

    # Iterates over all error messages, yielding the attribute and message.
    #
    # @yield [Symbol, String] the attribute name and error message
    #
    # @return [void]
    #
    # @example Iterate over all errors
    #   errors = CMDx::Errors.new
    #   errors.add(:name, "is required")
    #   errors.add(:email, "is invalid")
    #   errors.each { |attr, msg| puts "#{attr}: #{msg}" }
    #   # Output:
    #   # name: is required
    #   # email: is invalid
    def each
      errors.each_key do |key|
        errors[key].each { |val| yield(key, val) }
      end
    end

    # Formats an attribute and error message into a full error message.
    #
    # @param key [Symbol, String] the attribute name
    # @param value [String] the error message
    #
    # @return [String] the formatted full error message
    #
    # @example Format a full error message
    #   errors = CMDx::Errors.new
    #   errors.full_message(:name, "is required") # => "name is required"
    #
    # @example Format with different attribute types
    #   errors.full_message("email", "must be valid") # => "email must be valid"
    def full_message(key, value)
      "#{key} #{value}"
    end

    # Returns an array of all full error messages across all attributes.
    #
    # @return [Array<String>] array of formatted error messages
    #
    # @example Get all full error messages
    #   errors = CMDx::Errors.new
    #   errors.add(:name, "is required")
    #   errors.add(:email, "is invalid")
    #   errors.full_messages # => ["name is required", "email is invalid"]
    #
    # @example Empty errors return empty array
    #   errors = CMDx::Errors.new
    #   errors.full_messages # => []
    def full_messages
      errors.each_with_object([]) do |(key, arr), memo|
        arr.each { |val| memo << full_message(key, val) }
      end
    end
    alias to_a full_messages

    # Returns full error messages for a specific attribute.
    #
    # @param key [Symbol, String] the attribute name to get messages for
    #
    # @return [Array<String>] array of formatted error messages for the attribute
    #
    # @example Get full messages for a specific attribute
    #   errors = CMDx::Errors.new
    #   errors.add(:name, "is required")
    #   errors.add(:name, "is too short")
    #   errors.full_messages_for(:name) # => ["name is required", "name is too short"]
    #
    # @example Get messages for attribute without errors
    #   errors.full_messages_for(:missing) # => []
    def full_messages_for(key)
      return [] unless key?(key)

      errors[key].map { |val| full_message(key, val) }
    end

    # Checks if the error collection contains any errors.
    #
    # @return [Boolean] true if there are any errors present
    #
    # @example Check if errors are present
    #   errors = CMDx::Errors.new
    #   errors.invalid? # => false
    #   errors.add(:name, "is required")
    #   errors.invalid? # => true
    def invalid?
      !valid?
    end

    # Maps over all error messages, yielding the attribute and message to a block.
    #
    # Similar to {#each}, but returns an array of the block's return values
    # instead of iterating without collecting results.
    #
    # @yield [Symbol, String] the attribute name and error message
    # @yieldreturn [Object] the transformed value for each error message
    #
    # @return [Array<Object>] array of transformed values from the block
    #
    # @example Transform error messages to a custom format
    #   errors = CMDx::Errors.new
    #   errors.add(:name, "is required")
    #   errors.add(:email, "is invalid")
    #   result = errors.map { |attr, msg| "#{attr.upcase}: #{msg}" }
    #   result # => ["NAME: is required", "EMAIL: is invalid"]
    #
    # @example Extract only attribute names with errors
    #   errors.map { |attr, _msg| attr } # => [:name, :email]
    #
    # @example Return empty array for no errors
    #   empty_errors = CMDx::Errors.new
    #   empty_errors.map { |attr, msg| [attr, msg] } # => []
    def map
      errors.each_with_object([]) do |(key, _arr), memo|
        memo.concat(errors[key].map { |val| yield(key, val) })
      end
    end

    # Merges another hash of errors into this collection.
    #
    # When the same attribute exists in both collections, the error arrays
    # are combined and duplicates are removed.
    #
    # @param hash [Hash] hash of errors to merge, with attribute names as keys
    #
    # @return [Hash] the merged errors hash
    #
    # @example Merge errors from another hash
    #   errors = CMDx::Errors.new
    #   errors.add(:name, "is required")
    #   other_errors = { email: ["is invalid"], name: ["is too short"] }
    #   errors.merge!(other_errors)
    #   errors[:name] # => ["is required", "is too short"]
    #   errors[:email] # => ["is invalid"]
    #
    # @example Merge with duplicate errors
    #   errors.add(:age, "must be positive")
    #   errors.merge!(age: ["must be positive", "must be an integer"])
    #   errors[:age] # => ["must be positive", "must be an integer"]
    def merge!(hash)
      errors.merge!(hash) do |_, arr1, arr2|
        arr3 = arr1 + arr2
        arr3.uniq!
        arr3
      end
    end

    # Returns the raw error messages for a specific attribute.
    #
    # @param key [Symbol, String] the attribute name to get messages for
    #
    # @return [Array<String>] array of raw error messages for the attribute
    #
    # @example Get raw messages for an attribute
    #   errors = CMDx::Errors.new
    #   errors.add(:name, "is required")
    #   errors.add(:name, "is too short")
    #   errors.messages_for(:name) # => ["is required", "is too short"]
    #
    # @example Get messages for attribute without errors
    #   errors.messages_for(:missing) # => []
    def messages_for(key)
      return [] unless key?(key)

      errors[key]
    end
    alias [] messages_for

    # Checks if the error collection contains any errors.
    #
    # @return [Boolean] true if there are any errors present
    #
    # @example Check if errors are present
    #   errors = CMDx::Errors.new
    #   errors.present? # => false
    #   errors.add(:name, "is required")
    #   errors.present? # => true
    def present?
      !blank?
    end

    # Converts the error collection to a hash representation.
    #
    # @param full_messages [Boolean] whether to include full formatted messages
    #
    # @return [Hash] hash representation of errors
    #
    # @example Get raw error messages hash
    #   errors = CMDx::Errors.new
    #   errors.add(:name, "is required")
    #   errors.to_hash # => { name: ["is required"] }
    #
    # @example Get full formatted messages hash
    #   errors.to_hash(true) # => { name: ["name is required"] }
    #
    # @example Empty errors return empty hash
    #   errors = CMDx::Errors.new
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
