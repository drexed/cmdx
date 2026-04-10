# frozen_string_literal: true

module CMDx
  module Utils
    # Evaluates conditional expressions against a context.
    module Condition

      # Returns true when a conditional evaluates to true.
      #
      # @param conditional [Symbol, Proc, nil] the condition to evaluate
      # @param context [Object] the receiver for symbol/proc
      #
      # @return [Boolean]
      #
      # @rbs (untyped conditional, untyped context) -> bool
      def self.truthy?(conditional, context)
        return true if conditional.nil?

        result =
          case conditional
          when Symbol then context.__send__(conditional)
          when Proc   then context.instance_exec(&conditional)
          else conditional
          end

        !!result
      end

      # Returns true when a conditional evaluates to false.
      #
      # @param conditional [Symbol, Proc, nil] the condition to evaluate
      # @param context [Object] the receiver for symbol/proc
      #
      # @return [Boolean]
      #
      # @rbs (untyped conditional, untyped context) -> bool
      def self.falsy?(conditional, context)
        return true if conditional.nil?

        !truthy?(conditional, context)
      end

    end
  end
end
