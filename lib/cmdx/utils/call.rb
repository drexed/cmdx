# frozen_string_literal: true

module CMDx
  module Utils
    # Invokes a callable in the appropriate context.
    module Call

      # Invokes a callable reference.
      #
      # @param callable [Symbol, Proc, Object] the callable
      # @param task [Task, nil] the context for symbol/instance_exec
      # @param args [Array] arguments to pass
      #
      # @return [Object] the return value
      #
      # @rbs (untyped callable, untyped task, *untyped args) -> untyped
      def self.invoke(callable, task, *args)
        case callable
        when Symbol
          task.__send__(callable)
        when Proc
          if callable.arity.zero?
            task.instance_exec(&callable)
          else
            task.instance_exec(*args, &callable)
          end
        else
          callable.call(*args)
        end
      end

      # Invokes a callable with task and result arguments (for callbacks).
      #
      # @param callable [Symbol, Proc, Object] the callable
      # @param task [Task] the task instance
      # @param result [Result] the result instance
      #
      # @rbs (untyped callable, untyped task, untyped result) -> untyped
      def self.invoke_callback(callable, task, result)
        case callable
        when Symbol
          task.__send__(callable)
        when Proc
          if callable.arity.zero?
            task.instance_exec(&callable)
          else
            task.instance_exec(result, &callable)
          end
        else
          callable.call(task, result)
        end
      end

    end
  end
end
