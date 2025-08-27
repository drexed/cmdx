# frozen_string_literal: true

module Cmdx
  # Generates CMDx locale files for Rails applications
  #
  # Rails generator that copies CMDx locale files into the application's
  # config/locales directory. This allows applications to customize and extend
  # the default CMDx locale files.
  class LocaleGenerator < Rails::Generators::Base

    source_root File.expand_path("../../locales", __dir__)

    desc "Copies the locale with the given ISO 639 code"

    argument :locale, type: :string, default: "en", banner: "locale: en, es, fr, etc"

    # Copies the locale template to the Rails application
    #
    # Copies the specified locale file from the gem's locales directory to the
    # application's config/locales directory. If the locale file doesn't exist
    # in the gem, the generator will fail gracefully.
    #
    # @return [void]
    #
    # @example
    #   # Copy default (English) locale file
    #   rails generate cmdx:locale
    #   # => Creates config/locales/en.yml
    #
    #   # Copy Spanish locale file
    #   rails generate cmdx:locale es
    #   # => Creates config/locales/es.yml
    #
    def copy_locale_files
      copy_file("#{locale}.yml", "config/locales/#{locale}.yml")
    end

  end
end
