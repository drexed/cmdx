# frozen_string_literal: true

module CMDx
  module Utils
    module Condition

      # Evaluates a condition against a target.
      #
      # @param target [Object]
      # @param condition [Symbol, Proc, Boolean]
      # @return [Boolean]
      #
      # @rbs (untyped target, untyped condition) -> bool
      def self.evaluate(target, condition) # rubocop:disable Naming/PredicateMethod
        case condition
        when ::Symbol then target.respond_to?(condition, true) ? !!target.send(condition) : false
        when ::Proc then !!condition.call(target)
        else !!condition
        end
      end

    end
  end
end
