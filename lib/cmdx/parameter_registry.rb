# frozen_string_literal: true

module CMDx
  class ParameterRegistry

    attr_reader :registry, :errors

    def initialize
      @registry = []
      @errors = Set.new
    end

    def register(parameter)
      @registry << parameter
    end

    def call
      registry.each do |parameter|
        parameter.process!
        # errors.merge!(parameter.errors)
      end
    end

    def to_h
      registry.map(&:to_h)
    end

    def to_s
      registry.map(&:to_s).join("\n")
    end

  end
end
