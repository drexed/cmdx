# frozen_string_literal: true

module CMDx
  ##
  # Errors provides a collection-like interface for managing validation and execution errors
  # within CMDx tasks. It offers Rails-inspired methods for adding, querying, and formatting
  # error messages, making it easy to accumulate and present multiple error conditions.
  #
  # The Errors class is designed to work seamlessly with CMDx's parameter validation system,
  # automatically collecting validation failures and providing convenient methods for
  # error reporting and user feedback.
  #
  #
  # @example Basic error management
  #   errors = Errors.new
  #   errors.add(:email, "is required")
  #   errors.add(:email, "is invalid format")
  #   errors.add(:password, "is too short")
  #
  #   errors.empty?                    #=> false
  #   errors.size                      #=> 2 (attributes with errors)
  #   errors[:email]                   #=> ["is required", "is invalid format"]
  #   errors.full_messages             #=> ["email is required", "email is invalid format", "password is too short"]
  #
  # @example Task integration
  #   class CreateUserTask < CMDx::Task
  #     required :email, type: :string
  #     required :password, type: :string
  #
  #     def call
  #       validate_email
  #       validate_password
  #
  #       if errors.present?
  #         fail!(reason: "Validation failed", validation_errors: errors.full_messages)
  #       end
  #
  #       create_user
  #     end
  #
  #     private
  #
  #     def validate_email
  #       errors.add(:email, "is required") if email.blank?
  #       errors.add(:email, "is invalid") unless email.include?("@")
  #     end
  #
  #     def validate_password
  #       errors.add(:password, "is too short") if password.length < 8
  #     end
  #   end
  #
  # @example Error querying and formatting
  #   errors = Errors.new
  #   errors.add(:name, "cannot be blank")
  #   errors.add(:age, "must be a number")
  #
  #   # Checking for specific errors
  #   errors.key?(:name)                      #=> true
  #   errors.added?(:name, "cannot be blank") #=> true
  #   errors.of_kind?(:age, "must be positive") #=> false
  #
  #   # Getting messages
  #   errors.messages_for(:name)              #=> ["cannot be blank"]
  #   errors.full_messages_for(:name)         #=> ["name cannot be blank"]
  #
  #   # Converting to hash
  #   errors.to_hash                          #=> {:name => ["cannot be blank"], :age => ["must be a number"]}
  #   errors.to_hash(true)                    #=> {:name => ["name cannot be blank"], :age => ["age must be a number"]}
  #
  # @example Rails-style validation
  #   class ValidateUserTask < CMDx::Task
  #     required :user_data, type: :hash
  #
  #     def call
  #       user = user_data
  #
  #       errors.add(:email, "can't be blank") if user[:email].blank?
  #       errors.add(:email, "is invalid") unless valid_email?(user[:email])
  #       errors.add(:age, "must be at least 18") if user[:age] && user[:age] < 18
  #
  #       return if errors.invalid?
  #
  #       context.validated_user = user
  #     end
  #   end
  #
  # @see Task Task base class with errors attribute
  # @see Parameter Parameter validation integration
  # @see ValidationError Individual validation errors
  # @since 1.0.0
  class Errors

    __cmdx_attr_delegator :clear, :delete, :each, :empty?, :key?, :keys, :size, :values,
                          to: :errors

    ##
    # @!attribute [r] errors
    #   @return [Hash] internal hash storing error messages by attribute
    attr_reader :errors

    ##
    # @!method attribute_names
    #   @return [Array<Symbol>] list of attributes that have errors
    alias attribute_names keys

    ##
    # @!method blank?
    #   @return [Boolean] true if no errors are present
    alias blank? empty?

    ##
    # @!method valid?
    #   @return [Boolean] true if no errors are present
    alias valid? empty?

    ##
    # Alias for {#key?}. Checks if an attribute has error messages.
    alias has_key? key?

    ##
    # Alias for {#key?}. Checks if an attribute has error messages.
    alias include? key?

    ##
    # Initializes a new Errors collection.
    # Creates an empty hash to store error messages by attribute.
    #
    # @example
    #   errors = Errors.new
    #   errors.empty? #=> true
    def initialize
      @errors = {}
    end

    ##
    # Adds an error message to the specified attribute.
    # Messages are stored in arrays and automatically deduplicated.
    #
    # @param key [Symbol, String] the attribute name
    # @param value [String] the error message
    # @return [Array<String>] the updated array of messages for the attribute
    #
    # @example Adding multiple errors
    #   errors.add(:email, "is required")
    #   errors.add(:email, "is invalid format")
    #   errors.add(:email, "is required")  # Duplicate - ignored
    #   errors[:email] #=> ["is required", "is invalid format"]
    def add(key, value)
      errors[key] ||= []
      errors[key] << value
      errors[key].uniq!
    end
    alias []= add

    ##
    # Checks if a specific error message has been added to an attribute.
    #
    # @param key [Symbol, String] the attribute name
    # @param val [String] the error message to check for
    # @return [Boolean] true if the specific error exists
    #
    # @example
    #   errors.add(:name, "is required")
    #   errors.added?(:name, "is required")     #=> true
    #   errors.added?(:name, "is too long")     #=> false
    #   errors.of_kind?(:name, "is required")   #=> true (alias)
    def added?(key, val)
      return false unless key?(key)

      errors[key].include?(val)
    end
    alias of_kind? added?

    ##
    # Iterates over each error, yielding the attribute and message.
    # Flattens the error structure so each message is yielded individually.
    #
    # @yieldparam key [Symbol] the attribute name
    # @yieldparam val [String] the error message
    # @return [Enumerator] if no block given
    #
    # @example
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

    ##
    # Generates a full error message by combining attribute name and message.
    #
    # @param key [Symbol, String] the attribute name
    # @param value [String] the error message
    # @return [String] formatted full message
    #
    # @example
    #   errors.full_message(:email, "is required")  #=> "email is required"
    #   errors.full_message(:age, "must be positive") #=> "age must be positive"
    def full_message(key, value)
      "#{key} #{value}"
    end

    ##
    # Returns an array of all full error messages.
    # Combines attribute names with their error messages.
    #
    # @return [Array<String>] array of formatted error messages
    #
    # @example
    #   errors.add(:email, "is required")
    #   errors.add(:email, "is invalid")
    #   errors.add(:password, "is too short")
    #   errors.full_messages
    #   #=> ["email is required", "email is invalid", "password is too short"]
    def full_messages
      errors.each_with_object([]) do |(key, arr), memo|
        arr.each { |val| memo << full_message(key, val) }
      end
    end
    alias to_a full_messages

    ##
    # Returns full error messages for a specific attribute.
    #
    # @param key [Symbol, String] the attribute name
    # @return [Array<String>] array of full messages for the attribute
    #
    # @example
    #   errors.add(:email, "is required")
    #   errors.add(:email, "is invalid")
    #   errors.full_messages_for(:email)
    #   #=> ["email is required", "email is invalid"]
    #   errors.full_messages_for(:missing)  #=> []
    def full_messages_for(key)
      return [] unless key?(key)

      errors[key].map { |val| full_message(key, val) }
    end

    ##
    # Checks if any errors are present.
    #
    # @return [Boolean] true if errors exist
    #
    # @example
    #   errors = Errors.new
    #   errors.invalid?  #=> false
    #   errors.add(:name, "is required")
    #   errors.invalid?  #=> true
    def invalid?
      !valid?
    end

    ##
    # Merges another hash of errors into this collection.
    # Combines arrays of messages for attributes that exist in both collections.
    #
    # @param hash [Hash] hash of attribute => messages to merge
    # @return [Hash] the updated errors hash
    #
    # @example
    #   errors1 = Errors.new
    #   errors1.add(:email, "is required")
    #
    #   errors2 = { email: ["is invalid"], password: ["is too short"] }
    #   errors1.merge!(errors2)
    #
    #   errors1[:email] #=> ["is required", "is invalid"]
    #   errors1[:password] #=> ["is too short"]
    def merge!(hash)
      errors.merge!(hash) do |_, arr1, arr2|
        arr3 = arr1 + arr2
        arr3.uniq!
        arr3
      end
    end

    ##
    # Returns error messages for a specific attribute.
    #
    # @param key [Symbol, String] the attribute name
    # @return [Array<String>] array of error messages for the attribute
    #
    # @example
    #   errors.add(:email, "is required")
    #   errors.add(:email, "is invalid")
    #   errors.messages_for(:email)  #=> ["is required", "is invalid"]
    #   errors[:email]               #=> ["is required", "is invalid"] (alias)
    def messages_for(key)
      return [] unless key?(key)

      errors[key]
    end
    alias [] messages_for

    ##
    # Checks if any errors are present.
    #
    # @return [Boolean] true if errors exist
    #
    # @example
    #   errors = Errors.new
    #   errors.present?  #=> false
    #   errors.add(:name, "is required")
    #   errors.present?  #=> true
    def present?
      !blank?
    end

    ##
    # Converts the errors collection to a hash representation.
    #
    # @param full_messages [Boolean] whether to include full formatted messages
    # @return [Hash] hash representation of errors
    #
    # @example Raw messages
    #   errors.add(:email, "is required")
    #   errors.to_hash  #=> {:email => ["is required"]}
    #
    # @example Full messages
    #   errors.add(:email, "is required")
    #   errors.to_hash(true)  #=> {:email => ["email is required"]}
    #
    # @example Method aliases
    #   errors.messages              #=> same as to_hash
    #   errors.group_by_attribute    #=> same as to_hash
    #   errors.as_json               #=> same as to_hash
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
