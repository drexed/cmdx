# frozen_string_literal: true

module CMDx
  module CoreExt
    module ModuleExtensions

      def __cmdx_attr_delegator(*methods, **options)
        methods.each do |method|
          method_name = Utils::NameFormatter.call(method, options.fetch(:to), options)

          define_method(method_name) do |*args, **kwargs, &block|
            object = (options[:to] == :class ? self.class : send(options[:to]))

            unless options[:allow_missing] || object.respond_to?(method, true)
              raise NoMethodError,
                    "undefined method `#{method}' for #{options[:to]}"
            end

            object.send(method, *args, **kwargs, &block)
          end

          case options
          in { protected: true } then send(:protected, method_name)
          in { private: true } then send(:private, method_name)
          else # Leave public
          end
        end
      end

      def __cmdx_attr_setting(method, **options)
        define_singleton_method(method) do
          @cmd_facets ||= {}
          return @cmd_facets[method] if @cmd_facets.key?(method)

          value = superclass.__cmdx_try(method)
          return @cmd_facets[method] = value.dup unless value.nil?

          default = options[:default]
          value   = default.__cmdx_call
          @cmd_facets[method] = default.is_a?(Proc) ? value : value.dup
        end
      end

    end
  end
end

Module.include(CMDx::CoreExt::ModuleExtensions)
