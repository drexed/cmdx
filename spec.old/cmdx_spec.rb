# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx do
  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(CMDx::Configuration)
    end

    it "returns the same instance on multiple calls" do
      first_call = described_class.configuration
      second_call = described_class.configuration

      expect(first_call).to be(second_call)
    end

    it "initializes with default values" do
      config = described_class.configuration

      expect(config.logger).to be_a(Logger)
      expect(config.middlewares).to be_a(CMDx::MiddlewareRegistry)
      expect(config.callbacks).to be_a(CMDx::CallbackRegistry)
      expect(config.task_halt).to eq("failed")
      expect(config.workflow_halt).to eq("failed")
    end
  end

  describe ".configure" do
    let(:custom_logger) { Logger.new(StringIO.new) }

    it "yields the configuration object" do
      expect { |block| described_class.configure(&block) }.to yield_with_args(CMDx::Configuration)
    end

    it "returns the configuration object" do
      result = described_class.configure { |config| config.task_halt = ["failed"] }

      expect(result).to be_a(CMDx::Configuration)
      expect(result).to be(described_class.configuration)
    end

    it "allows modification of configuration attributes" do
      described_class.configure do |config|
        config.logger = custom_logger
        config.task_halt = %w[failed skipped]
        config.workflow_halt = ["failed"]
      end

      expect(described_class.configuration.logger).to be(custom_logger)
      expect(described_class.configuration.task_halt).to eq(%w[failed skipped])
      expect(described_class.configuration.workflow_halt).to eq(["failed"])
    end

    it "raises ArgumentError when no block is given" do
      expect { described_class.configure }.to raise_error(ArgumentError, "block required")
    end
  end

  describe ".reset_configuration!" do
    let(:custom_logger) { Logger.new(StringIO.new) }

    before do
      described_class.configure do |config|
        config.logger = custom_logger
        config.task_halt = %w[failed skipped]
      end
    end

    it "returns a new Configuration instance" do
      original_config = described_class.configuration
      reset_config = described_class.reset_configuration!

      expect(reset_config).to be_a(CMDx::Configuration)
      expect(reset_config).not_to be(original_config)
    end

    it "resets all configuration values to defaults" do
      described_class.reset_configuration!

      expect(described_class.configuration.logger).not_to be(custom_logger)
      expect(described_class.configuration.task_halt).to eq("failed")
      expect(described_class.configuration.workflow_halt).to eq("failed")
    end

    it "creates fresh middleware and callback registries" do
      original_middlewares = described_class.configuration.middlewares
      original_callbacks = described_class.configuration.callbacks

      described_class.reset_configuration!

      expect(described_class.configuration.middlewares).not_to be(original_middlewares)
      expect(described_class.configuration.callbacks).not_to be(original_callbacks)
      expect(described_class.configuration.middlewares).to be_a(CMDx::MiddlewareRegistry)
      expect(described_class.configuration.callbacks).to be_a(CMDx::CallbackRegistry)
    end
  end

  describe "configuration persistence" do
    it "maintains configuration across multiple accesses" do
      custom_logger = Logger.new(StringIO.new)

      described_class.configure { |config| config.logger = custom_logger }

      expect(described_class.configuration.logger).to be(custom_logger)
      expect(described_class.configuration.logger).to be(custom_logger)
    end

    it "maintains configuration after calling configure multiple times" do
      first_logger = Logger.new(StringIO.new)
      second_logger = Logger.new(StringIO.new)

      described_class.configure { |config| config.logger = first_logger }
      described_class.configure { |config| config.task_halt = %w[failed skipped] }

      expect(described_class.configuration.logger).to be(first_logger)
      expect(described_class.configuration.task_halt).to eq(%w[failed skipped])

      described_class.configure { |config| config.logger = second_logger }

      expect(described_class.configuration.logger).to be(second_logger)
      expect(described_class.configuration.task_halt).to eq(%w[failed skipped])
    end
  end
end
