# frozen_string_literal: true

module CMDx
  module Utils
    module Delegate

      module_function

      def call(target, *methods, **options)
        methods.each do |method|
          subject   = options.fetch(:to)
          signature = Utils::Signature.call(subject, method, options)

          # TODO: raise error if signature is already defined

          target.define_method(signature) do |*args, **kwargs, &block|
            object =
              case subject
              when :class then target.class
              else target.send(subject)
              end

            unless options[:allow_missing] || object.respond_to?(method, true)
              raise DelegationError,
                    "undefined method `#{method}' for #{subject}"
            end

            object.send(method, *args, **kwargs, &block)
          end

          case options
          in { private: true } then target.send(:private, signature)
          in { protected: true } then target.send(:protected, signature)
          end
        end
      end

    end
  end
end
