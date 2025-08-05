# frozen_string_literal: true

module CMDx
  class Event

    extend Forwardable

    attr_reader :name, :data, :timestamp

    def_delegators :data, :[], :to_h, :to_s

    def initialize(name, data = {})
      @name = name.to_s
      @data = data.freeze
      @timestamp = Time.now.utc
    end

    def to_h
      {
        name:,
        data:,
        timestamp:
      }
    end

    def to_s
      Utils::Format.to_str(to_h)
    end

  end
end
