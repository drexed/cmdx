# frozen_string_literal: true

ENV["SKIP_CMDX_FREEZING"] = "1"
ENV["TZ"] = "UTC"

require "bundler/setup"
require "rspec"

require "cmdx"
require "cmdx/rspec"

spec_path = Pathname.new(File.expand_path("../spec", File.dirname(__FILE__)))

%w[config helpers].each do |dir|
  Dir.glob(spec_path.join("support/#{dir}/**/*.rb"))
     .sort_by { |f| [f.split("/").size, f] }
     .each { |f| load(f) }
end

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

  config.include CMDx::Testing::TaskBuilders
  config.include CMDx::Testing::WorkflowBuilders

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
