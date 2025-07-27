# frozen_string_literal: true

module CMDx
  module Utils
    module Locale

      EN = YAML.load_file(File.expand_path("../../../lib/locales/en.yml", __dir__)).freeze

      module_function

      def t(key, **options)
        options[:default] ||= EN.dig("en", *key.to_s.split("."))
        return I18n.t(key, **options) if defined?(I18n)

        text = options.delete(:default)
        return "Translation missing: #{key}" if text.nil?

        subs = options.transform_keys { |key| "%{#{key}}" }
        regx = Regexp.union(subs.keys)
        text.gsub!(regx, subs) || text
      end

    end
  end
end
