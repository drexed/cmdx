# frozen_string_literal: true

module CMDx
  class Errors

    __cmdx_attr_delegator :clear, :delete, :each, :empty?, :key?, :keys, :size, :values, to: :errors

    attr_reader :errors

    alias attribute_names keys
    alias blank? empty?
    alias valid? empty?
    alias has_key? key?
    alias include? key?

    def initialize
      @errors = {}
    end

    def add(key, value)
      errors[key] ||= []
      errors[key] << value
      errors[key].uniq!
    end
    alias []= add

    def added?(key, val)
      return false unless key?(key)

      errors[key].include?(val)
    end
    alias of_kind? added?

    def each
      errors.each_key do |key|
        errors[key].each { |val| yield(key, val) }
      end
    end

    def full_message(key, value)
      "#{key} #{value}"
    end

    def full_messages
      errors.each_with_object([]) do |(key, arr), memo|
        arr.each { |val| memo << full_message(key, val) }
      end
    end
    alias to_a full_messages

    def full_messages_for(key)
      return [] unless key?(key)

      errors[key].map { |val| full_message(key, val) }
    end

    def invalid?
      !valid?
    end

    def merge!(hash)
      errors.merge!(hash) do |_, arr1, arr2|
        arr3 = arr1 + arr2
        arr3.uniq!
        arr3
      end
    end

    def messages_for(key)
      return [] unless key?(key)

      errors[key]
    end
    alias [] messages_for

    def present?
      !blank?
    end

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
