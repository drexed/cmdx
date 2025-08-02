# frozen_string_literal: true

module CMDx
  class Errors

    extend Forwardable

    attr_reader :messages

    def_delegators :messages, :empty?, :to_h

    def initialize
      @messages = {}
    end

    def add(attribute, message)
      return if message.empty?

      messages[attribute] ||= Set.new
      messages[attribute] << message
    end

    def for?(attribute)
      return false unless messages.key?(attribute)

      !messages[attribute].empty?
    end

    def to_s
      messages.each_with_object([]) do |(attribute, messages), memo|
        messages.each { |message| memo << "#{attribute} #{message}" }
      end.join(". ")
    end

  end
end
