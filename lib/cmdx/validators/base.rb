# frozen_string_literal: true

module CMDx
  module Validators
    class Base

      # Utils::Delegate.call(self, :task, to: :parameter)

      attr_reader :parameter, :options

      def initialize(parameter, options = {})
        @parameter = parameter
        @options   = options
      end

      def self.call(parameter, options = {})
        new(parameter, options)
      end

      def call
        raise UndefinedCallError, "call method not defined in #{self.class.name}"
      end

    end
  end
end
