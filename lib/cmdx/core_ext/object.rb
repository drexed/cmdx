# frozen_string_literal: true

module CMDx
  module CoreExt
    module ObjectExtensions

      alias __cmdx_respond_to? respond_to?

      def __cmdx_try(key, ...)
        if key.is_a?(Proc)
          return instance_eval(&key) unless is_a?(Module) || key.inspect.include?("(lambda)")

          key.call(...)
        elsif respond_to?(key, true)
          send(key, ...)
        elsif is_a?(Hash)
          __cmdx_fetch(key)
        end
      end

      def __cmdx_eval(options = {})
        if options[:if] && options[:unless]
          __cmdx_try(options[:if]) && !__cmdx_try(options[:unless])
        elsif options[:if]
          __cmdx_try(options[:if])
        elsif options[:unless]
          !__cmdx_try(options[:unless])
        else
          options.fetch(:default, true)
        end
      end

      def __cmdx_yield(key, ...)
        if key.is_a?(Symbol) || key.is_a?(String)
          return key unless respond_to?(key, true)

          send(key, ...)
        elsif is_a?(Hash) || key.is_a?(Proc)
          __cmdx_try(key, ...)
        else
          key
        end
      end

      def __cmdx_call(...)
        return self unless respond_to?(:call)

        call(...)
      end

    end
  end
end

Object.include(CMDx::CoreExt::ObjectExtensions)
