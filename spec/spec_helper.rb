# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
ENV["TZ"] = "UTC"

require "bundler/setup"
require "rspec"

require "cmdx"

spec_path = Pathname.new(File.expand_path("../spec", File.dirname(__FILE__)))

RSpec.configure do |config|
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  config.define_derived_metadata do |meta|
    meta[:aggregate_failures] = true
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    CMDx.configuration.logger = Logger.new(nil)
    CMDx::Chain.clear
  end

  config.after do
    CMDx.reset_configuration!
    CMDx::Chain.clear
  end

  config.after(:all) do
    temp_path = spec_path.join("generators/tmp")
    FileUtils.remove_dir(temp_path) if File.directory?(temp_path)
  end
end

# Load support files after RSpec is configured
%w[config].each do |dir|
  Dir.glob(spec_path.join("support/#{dir}/**/*.rb"))
     .sort_by { |f| [f.split("/").size, f] }
     .each { |f| load(f) }
end
