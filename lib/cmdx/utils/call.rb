# frozen_string_literal: true

module CMDx
  module Utils
    module Call

      extend self

      def invoke!(target, callable, *args, **kwargs, &)
        case callable
        when Symbol, String then target.send(callable, *args, **kwargs, &)
        when Proc then target.instance_exec(*args, **kwargs, &callable)
        else
          raise "cannot invoke #{callable}" unless callable.respond_to?(:call)

          callable.call(*args, **kwargs, &)
        end
      end

    end
  end
end
