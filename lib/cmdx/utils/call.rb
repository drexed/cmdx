# frozen_string_literal: true

module CMDx
  module Utils
    module Call

      extend self

      def invoke!(target, callable, *args, **kwargs, &)
        if callable.is_a?(Symbol) || callable.is_a?(String)
          target.send(callable, *args, **kwargs, &)
        elsif callable.is_a?(Proc)
          target.instance_exec(*args, **kwargs, &callable)
        elsif callable.respond_to?(:call)
          callable.call(*args, **kwargs, &)
        else
          raise "cannot invoke #{callable}"
        end
      end

    end
  end
end
