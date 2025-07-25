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
        parameter.call
        # errors.merge!(parameter.errors)
      end
    end

  end
end
