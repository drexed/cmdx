# frozen_string_literal: true

# TODO: rename to CMDx::Translation
module CMDx
  module Utils
    module Locale

      EN = YAML.load_file(File.expand_path("../../../lib/locales/en.yml", __dir__)).freeze

      extend self

      def t(key, **options)
        options[:default] ||= EN.dig("en", *key.to_s.split("."))
        return I18n.t(key, **options) if defined?(I18n)

        message = options.delete(:default)
        return "Translation missing: #{key}" if message.nil?

        message % options
      end

    end
  end
end
