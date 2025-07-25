# frozen_string_literal: true

module CMDx
  module TaskAttribute

    module_function

    def define!(parameter)
      parameter.klass.tap do |klass|
        klass.define_method(parameter.signature) do
          @_attributes ||= {}

          unless @_attributes.key?(parameter.signature)
            begin
              parameter_value = ParameterValue.call(self, parameter)
            rescue CoercionError, ValidationError => e
              parameter.errors.add(parameter.signature, e.message)
              errors.merge!(parameter.errors.to_hash)
            ensure
              @_attributes[parameter.signature] = parameter_value
            end
          end

          @_attributes[parameter.signature]
        end

        klass.send(:private, parameter.signature)
      end
    end

  end
end
