# frozen_string_literal: true

module CMDx
  class Errors

    extend Forwardable

    def_delegators :errors, :clear, :delete, :empty?, :key?, :keys, :size, :values

    attr_reader :errors

    def initialize
      @errors = {}
    end

    def add(attribute, message)
      errors[attribute] ||= Set.new
      errors[attribute] << message
    end
    alias []= add

    def added?(attribute, message = nil)
      return key?(attribute) if message.nil?

      messages_for(attribute).include?(val)
    end

    def each
      errors.each_key do |attribute|
        messages_for(attribute).each do |message|
          yield(attribute, message)
        end
      end
    end

    def full_message(attribute, message)
      "#{attribute} #{message}"
    end

    def full_messages
      errors.each_with_object([]) do |(attribute, messages), memo|
        messages.each { |message| memo << full_message(attribute, message) }
      end
    end
    alias to_a full_messages

    def full_messages_for(attribute)
      messages_for(attribute).map { |message| full_message(attribute, message) }
    end

    def merge!(hash)
      errors.merge!(hash) do |_attribute, messages1, messages2|
        messages1 + messages2
      end
    end

    def messages_for(key)
      Array(errors[key])
    end
    alias [] messages_for

    def to_hash(full_messages = false)
      return errors unless full_messages

      errors.each_with_object({}) do |(attribute, messages), memo|
        memo[attribute] = messages.map { |message| full_message(attribute, message) }
      end
    end
    alias messages to_hash

  end
end
