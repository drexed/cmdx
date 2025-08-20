# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx do
  after do
    described_class.reset_configuration!
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(CMDx::Configuration)
    end

    it "returns the same instance on subsequent calls" do
      first_call = described_class.configuration
      second_call = described_class.configuration

      expect(first_call).to be(second_call)
    end

    context "when @configuration is already set" do
      let(:custom_config) { CMDx::Configuration.new }

      before do
        described_class.instance_variable_set(:@configuration, custom_config)
      end

      after do
        # Skip the automatic reset for this test
        described_class.instance_variable_set(:@configuration, nil)
      end

      it "returns the existing configuration" do
        expect(described_class.configuration).to be(custom_config)
      end

      it "reuses the existing instance" do
        first_config = described_class.configuration
        second_config = described_class.configuration

        expect(first_config).to be(second_config)
        expect(first_config).to be(custom_config)
      end
    end

    context "when @configuration is nil" do
      before do
        described_class.instance_variable_set(:@configuration, nil)
      end

      it "creates and returns a new Configuration instance" do
        expect(described_class.configuration).to be_a(CMDx::Configuration)
      end
    end
  end

  describe ".configure" do
    it "yields the configuration object" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(CMDx::Configuration)
    end

    it "returns the configuration object" do
      result = described_class.configure { nil }

      expect(result).to be(described_class.configuration)
    end

    it "allows configuration modification within the block" do
      custom_breakpoints = %w[custom_failed timeout]

      described_class.configure do |config|
        config.task_breakpoints = custom_breakpoints
      end

      expect(described_class.configuration.task_breakpoints).to eq(custom_breakpoints)
    end

    it "passes the same configuration instance to the block" do
      original_config = described_class.configuration

      described_class.configure do |config|
        expect(config).to be(original_config)
      end
    end

    context "without a block" do
      it "raises ArgumentError with descriptive message" do
        expect { described_class.configure }.to raise_error(ArgumentError, "block required")
      end
    end

    context "with multiple configuration changes" do
      let(:custom_logger) { Logger.new($stderr, progname: "test") }
      let(:custom_breakpoints) { %w[error timeout] }

      it "applies all changes correctly" do
        described_class.configure do |config|
          config.task_breakpoints = custom_breakpoints
          config.logger = custom_logger
        end

        config = described_class.configuration
        expect(config.task_breakpoints).to eq(custom_breakpoints)
        expect(config.logger).to eq(custom_logger)
      end
    end
  end

  describe ".reset_configuration!" do
    let(:custom_logger) { Logger.new($stderr, progname: "test") }
    let(:custom_breakpoints) { %w[custom_failed] }

    before do
      # Modify the configuration first
      described_class.configure do |config|
        config.task_breakpoints = custom_breakpoints
        config.workflow_breakpoints = custom_breakpoints
        config.logger = custom_logger
      end
    end

    after do
      # Skip the automatic reset for these tests since we're testing reset
      described_class.instance_variable_set(:@configuration, nil)
    end

    it "creates a new Configuration instance" do
      original_config = described_class.configuration
      described_class.reset_configuration!
      expect(described_class.configuration).not_to be(original_config)
      expect(described_class.configuration).to be_a(CMDx::Configuration)
    end

    it "resets all breakpoints to default values" do
      described_class.reset_configuration!
      config = described_class.configuration

      expect(config.task_breakpoints).to eq(%w[failed])
      expect(config.workflow_breakpoints).to eq(%w[failed])
    end

    it "resets logger to default configuration" do
      described_class.reset_configuration!
      logger = described_class.configuration.logger

      expect(logger.progname).to eq("cmdx")
      expect(logger.formatter).to be_a(CMDx::LogFormatters::Line)
      expect(logger.level).to eq(Logger::INFO)
    end

    it "resets all registries to their default state" do
      described_class.reset_configuration!
      config = described_class.configuration

      expect(config.middlewares.registry).to be_empty
      expect(config.callbacks.registry).to be_empty
      expect(config.coercions.registry.keys).to include(
        :array, :string, :integer, :boolean, :float, :hash
      )
      expect(config.validators.registry.keys).to include(
        :presence, :format, :inclusion, :exclusion, :length, :numeric
      )
    end

    it "clears the memoized @configuration variable" do
      old_object_id = described_class.configuration.object_id
      described_class.reset_configuration!

      expect(described_class.configuration.object_id).not_to eq(old_object_id)
    end

    context "when called multiple times" do
      it "creates a fresh instance each time" do
        described_class.reset_configuration!
        first_reset = described_class.configuration

        described_class.reset_configuration!
        second_reset = described_class.configuration

        expect(first_reset).not_to be(second_reset)
      end
    end

    context "when configuration is not modified" do
      it "still creates a new instance" do
        original_config = described_class.configuration
        described_class.reset_configuration!

        expect(described_class.configuration).not_to be(original_config)
      end
    end

    context "when configuration has custom registries" do
      let(:custom_middleware) { CMDx::MiddlewareRegistry.new }
      let(:custom_callback) { CMDx::CallbackRegistry.new }

      before do
        described_class.configure do |config|
          config.middlewares = custom_middleware
          config.callbacks = custom_callback
        end
      end

      it "resets to new default registry instances" do
        described_class.reset_configuration!
        config = described_class.configuration

        expect(config.middlewares).not_to be(custom_middleware)
        expect(config.callbacks).not_to be(custom_callback)
        expect(config.middlewares).to be_a(CMDx::MiddlewareRegistry)
        expect(config.callbacks).to be_a(CMDx::CallbackRegistry)
      end
    end
  end
end
