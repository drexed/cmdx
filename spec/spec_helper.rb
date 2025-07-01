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

  # Global test doubles setup - these provide consistent values across all tests
  config.before do
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC, :millisecond).and_return(0)
    allow(Process).to receive(:pid).and_return(3784)
    allow(SecureRandom).to receive(:uuid).and_return("018c2b95-b764-7615-a924-cc5b910ed1e5")
    allow(Time).to receive(:now).and_return(Time.local(2022, 7, 17, 18, 43, 15))

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
%w[config helpers matchers tasks shared_examples].each do |dir|
  Dir.glob(spec_path.join("support/#{dir}/**/*.rb"))
     .sort_by { |f| [f.split("/").size, f] }
     .each { |f| load(f) }
end
