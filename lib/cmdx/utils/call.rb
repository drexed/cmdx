# frozen_string_literal: true

module CMDx
  module Utils
    module Call

      # Invokes a callable (Symbol, Proc, or object with .call).
      #
      # @param callable [Symbol, Proc, Object]
      # @param target [Object] receiver for Symbol callables
      # @param args [Array] additional arguments
      #
      # @rbs (untyped callable, untyped target, *untyped args) -> untyped
      def self.invoke(callable, target, *args)
        case callable
        when ::Symbol then target.send(callable, *args)
        when ::Proc then callable.call(*args)
        else callable.call(target, *args) if callable.respond_to?(:call)
        end
      end

    end
  end
end
