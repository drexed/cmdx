# frozen_string_literal: true

module Cmdx
  class InstallGenerator < Rails::Generators::Base

    source_root File.expand_path("templates", __dir__)

    desc "Creates CMDx initializer with global configuration settings"

    def copy_initializer_file
      copy_file("install.rb", "config/initializers/cmdx.rb")
    end

  end
end
