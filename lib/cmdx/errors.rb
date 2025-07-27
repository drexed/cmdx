# frozen_string_literal: true

module CMDx
  class Errors

    extend Forwardable

    def_delegators :messages, :empty?

    attr_reader :messages

    alias to_h messages

    def initialize
      @messages = {}
    end

    def add(attribute, message)
      messages[attribute] ||= []
      messages[attribute] << message
      messages[attribute].uniq!
    end

    def merge!(hash)
      messages.merge!(hash) do |_attribute, messages1, messages2|
        messages1 + messages2
      end
    end

    def to_s
      messages.each_with_object([]) do |(attribute, messages), memo|
        messages.each { |message| memo << "#{attribute} #{message}" }
      end.join(". ")
    end

  end
end
