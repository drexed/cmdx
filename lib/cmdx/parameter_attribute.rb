# frozen_string_literal: true

module CMDx
  module ParameterAttribute

    module_function

    def call(parameter)
      parameter.klass.tap do |klass|
        klass.define_method(parameter.signature) do
          @parameter_value_cache ||= {}

          unless @parameter_value_cache.key?(parameter.signature)
            begin
              parameter_value = ParameterValue.call(self, parameter)
            rescue CoercionError, ValidationError => e
              parameter.errors.add(parameter.signature, e.message)
              errors.merge!(parameter.errors.to_hash)
            ensure
              @parameter_value_cache[parameter.signature] = parameter_value
            end
          end

          @parameter_value_cache[parameter.signature]
        end

        klass.send(:private, parameter.signature)
      end
    end

  end
end
