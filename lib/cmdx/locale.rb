# frozen_string_literal: true

require "yaml"

module CMDx
  # Minimal i18n: +I18n+ when loaded, else English defaults from YAML when present.
  module Locale

    extend self

    # @param key [String, Symbol]
    # @param options [Hash]
    # @return [String]
    def translate(key, **options)
      options[:default] ||= default_for(key)
      return ::I18n.t(key, **options) if defined?(::I18n)

      case message = options.delete(:default)
      when String then format_string(message, options)
      when NilClass then "Translation missing: #{key}"
      else message
      end
    end

    alias t translate

    private

    # @param message [String]
    # @param options [Hash]
    # @return [String]
    def format_string(message, options)
      return message if options.empty?

      message % options
    end

    # @param key [String, Symbol]
    # @return [String, nil]
    def default_for(key)
      root = translations["en"] || translations[:en]
      return nil unless root.is_a?(Hash)

      parts = key.to_s.split(".")
      value = parts.reduce(root) do |h, p|
        break nil unless h.is_a?(Hash)

        h[p] || h[p.to_sym]
      end
      value.is_a?(String) ? value : nil
    end

    # @return [Hash]
    def translations
      @translations ||= begin
        path = CMDx.gem_path.join("lib/locales/en.yml")
        if path.file?
          YAML.safe_load(path.read, permitted_classes: [Symbol], aliases: true) || {}
        else
          {}
        end
      end
    end

  end
end
