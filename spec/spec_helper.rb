# frozen_string_literal: true

ENV["TZ"] = "Etc/UTC"

require "bundler/setup"
require "rspec"

require "cmdx"

RSpec.configure do |config|
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.define_derived_metadata do |meta|
    meta[:aggregate_failures] = true
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    CMDx.reset_configuration!
    CMDx.configuration.logger = Logger.new(nil)
    CMDx::Chain.clear
    CMDx::Middlewares::Correlate.clear
  end

  config.after do
    CMDx.reset_configuration!
    CMDx::Chain.clear
    CMDx::Middlewares::Correlate.clear
  end
end
