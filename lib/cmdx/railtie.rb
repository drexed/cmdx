# frozen_string_literal: true

module CMDx
  class Railtie < Rails::Railtie

    initializer "cmdx.configure_rails" do
      locale_path = File.expand_path("../../locales/*.yml", __dir__)
      I18n.load_path += Dir[locale_path] if defined?(I18n)

      CMDx.configure do |config|
        config.logger = Rails.logger if defined?(Rails.logger)
        config.backtrace_cleaner = ->(bt) { Rails.backtrace_cleaner.clean(bt) } if defined?(Rails.backtrace_cleaner)
      end
    end

  end
end
