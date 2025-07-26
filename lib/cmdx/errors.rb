# frozen_string_literal: true

module CMDx
  class Errors

    extend Forwardable

    def_delegators :errors, :empty?

    attr_reader :errors

    alias to_h errors

    def initialize
      @errors = {}
    end

    def add(attribute, message)
      errors[attribute] ||= Set.new
      errors[attribute] << message
    end

    def merge!(hash)
      errors.merge!(hash) do |_attribute, messages1, messages2|
        messages1 + messages2
      end
    end

    def to_s
      errors.each_with_object([]) do |(attribute, messages), memo|
        messages.each { |message| memo << "#{attribute} #{message}" }
      end.join(". ")
    end

  end
end
