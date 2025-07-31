# frozen_string_literal: true

module CMDx
  class Errors

    extend Forwardable

    def_delegators :messages, :empty?, :to_h

    attr_reader :messages

    def initialize
      @messages = {}
    end

    def add(attribute, message)
      return if message.empty?

      messages[attribute] = message
    end

    def to_s
      messages.each_with_object([]) do |(attribute, messages), memo|
        messages.each { |message| memo << "#{attribute} #{message}" }
      end.join(". ")
    end

  end
end
