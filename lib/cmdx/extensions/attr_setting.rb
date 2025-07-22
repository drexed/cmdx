# frozen_string_literal: true

module CMDx
  module Extensions
    module AttrSetting

      def attr_setting(method, **options)
        define_singleton_method(method) do
          @_cmdx_settings ||= {}
          return @_cmdx_settings[method] if @_cmdx_settings.key?(method)

          value = Try.call(superclass, method)
          return @_cmdx_settings[method] = value.dup unless value.nil?

          default = options[:default]
          value   = Call.call(default)
          @_cmdx_settings[method] = default.is_a?(Proc) ? value : value.dup
        end
      end

    end
  end
end
