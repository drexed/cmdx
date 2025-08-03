# frozen_string_literal: true

module CMDx
  module Locale

    extend self

    EN = YAML.load_file(CMDx.gem_path.join("locales/en.yml")).freeze
    private_constant :EN

    def translate(key, **options)
      options[:default] ||= EN.dig("en", *key.to_s.split("."))
      return I18n.t(key, **options) if defined?(I18n)

      case message = options.delete(:default)
      when NilClass then "Translation missing: #{key}"
      when String then message % options
      else message
      end
    end

  end
end
