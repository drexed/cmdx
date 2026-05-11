# frozen_string_literal: true

require "spec_helper"

# rubocop:disable RSpec/MultipleDescribes
RSpec.describe CMDx::Configuration do
  subject(:config) { described_class.new }

  describe "#initialize" do
    it "builds fresh registries for middlewares, callbacks, coercions, validators, telemetry" do
      expect(config.middlewares).to be_a(CMDx::Middlewares)
      expect(config.callbacks).to be_a(CMDx::Callbacks)
      expect(config.coercions).to be_a(CMDx::Coercions)
      expect(config.validators).to be_a(CMDx::Validators)
      expect(config.telemetry).to be_a(CMDx::Telemetry)
    end

    it "defaults locale, backtrace_cleaner, and log settings" do
      expect(config).to have_attributes(
        default_locale: "en",
        backtrace_cleaner: nil,
        strict_context: false,
        log_level: nil,
        log_formatter: nil,
        correlation_id: nil
      )
      expect(config.logger).to be_a(Logger)
      expect(config.logger.level).to eq(Logger::INFO)
      expect(config.logger.formatter).to be_a(CMDx::LogFormatters::Line)
    end

    it "gives each instance independent registries" do
      other = described_class.new
      expect(config.middlewares).not_to be(other.middlewares)
      expect(config.callbacks).not_to be(other.callbacks)
    end
  end

  describe "attribute assignment" do
    it "allows reading and writing each configuration attribute" do
      logger = Logger.new(nil)
      cleaner = ->(bt) { bt }
      correlation_id = -> { "req-1" }

      config.logger = logger
      config.backtrace_cleaner = cleaner
      config.default_locale = "fr"
      config.strict_context = true
      config.correlation_id = correlation_id

      expect(config.logger).to be(logger)
      expect(config.backtrace_cleaner).to be(cleaner)
      expect(config.default_locale).to eq("fr")
      expect(config.strict_context).to be(true)
      expect(config.correlation_id).to be(correlation_id)
    end
  end
end

RSpec.describe CMDx do
  describe ".configuration" do
    it "returns the same Configuration instance across calls" do
      first = described_class.configuration
      second = described_class.configuration
      expect(first).to be(second)
    end

    it "returns a Configuration" do
      expect(described_class.configuration).to be_a(CMDx::Configuration)
    end
  end

  describe ".configure" do
    it "yields the configuration and returns it" do
      yielded = nil
      result = described_class.configure { |c| yielded = c }

      expect(yielded).to be(described_class.configuration)
      expect(result).to be(described_class.configuration)
    end

    it "raises without a block" do
      expect { described_class.configure }.to raise_error(ArgumentError, /CMDx\.configure requires a block/)
    end
  end

  describe ".reset_configuration!" do
    it "replaces the configuration with a new instance" do
      old = described_class.configuration
      described_class.reset_configuration!
      expect(described_class.configuration).not_to be(old)
    end

    it "clears Task-level instance variables so they re-pull from config" do
      described_class.reset_configuration!

      expect(CMDx::Task.instance_variable_get(:@middlewares)).to be_nil
      expect(CMDx::Task.instance_variable_get(:@callbacks)).to be_nil
      expect(CMDx::Task.instance_variable_get(:@coercions)).to be_nil
      expect(CMDx::Task.instance_variable_get(:@validators)).to be_nil
      expect(CMDx::Task.instance_variable_get(:@telemetry)).to be_nil
    end
  end
end
# rubocop:enable RSpec/MultipleDescribes
