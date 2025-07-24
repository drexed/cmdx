# frozen_string_literal: true

module CMDx
  class ParameterRegistry

    extend Forwardable

    def_delegators :parameters, :each

    attr_reader :parameters, :errors

    def initialize
      @parameters = []
      @errors = Set.new
    end

    def register(parameter)
      @parameters << parameter
    end

    def call
      parameters.each do |parameter|
        parameter.call
        errors.merge!(parameter.errors)
      end
    end

  end
end
