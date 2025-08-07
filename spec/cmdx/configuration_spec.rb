# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Configuration do
  subject { described_class.new }

  describe "#initialize" do
    it "sets up default middlewares registry" do
      expect(subject.middlewares).to be_a(CMDx::MiddlewareRegistry)
      expect(subject.middlewares.registry).to eq([])
    end

    it "sets up default callbacks registry" do
      expect(subject.callbacks).to be_a(CMDx::CallbackRegistry)
      expect(subject.callbacks.registry).to eq({})
    end

    it "sets up default coercions registry" do
      expect(subject.coercions).to be_a(CMDx::CoercionRegistry)
      expect(subject.coercions.registry).to include(
        array: CMDx::Coercions::Array,
        boolean: CMDx::Coercions::Boolean,
        string: CMDx::Coercions::String,
        integer: CMDx::Coercions::Integer
      )
    end

    it "sets up default validators registry" do
      expect(subject.validators).to be_a(CMDx::ValidatorRegistry)
      expect(subject.validators.registry).to include(
        presence: CMDx::Validators::Presence,
        format: CMDx::Validators::Format,
        inclusion: CMDx::Validators::Inclusion
      )
    end

    it "sets task_breakpoints to default values" do
      expect(subject.task_breakpoints).to eq(%w[failed])
    end

    it "sets workflow_breakpoints to default values" do
      expect(subject.workflow_breakpoints).to eq(%w[failed])
    end

    it "sets up default logger with correct configuration" do
      expect(subject.logger).to be_a(Logger)
      expect(subject.logger.progname).to eq("cmdx")
      expect(subject.logger.formatter).to be_a(CMDx::LogFormatters::Line)
      expect(subject.logger.level).to eq(Logger::INFO)
    end
  end

  describe "#middlewares=" do
    let(:custom_registry) { CMDx::MiddlewareRegistry.new }

    it "sets middlewares to the provided value" do
      subject.middlewares = custom_registry
      expect(subject.middlewares).to eq(custom_registry)
    end
  end

  describe "#callbacks=" do
    let(:custom_registry) { CMDx::CallbackRegistry.new }

    it "sets callbacks to the provided value" do
      subject.callbacks = custom_registry
      expect(subject.callbacks).to eq(custom_registry)
    end
  end

  describe "#coercions=" do
    let(:custom_registry) { CMDx::CoercionRegistry.new }

    it "sets coercions to the provided value" do
      subject.coercions = custom_registry
      expect(subject.coercions).to eq(custom_registry)
    end
  end

  describe "#validators=" do
    let(:custom_registry) { CMDx::ValidatorRegistry.new }

    it "sets validators to the provided value" do
      subject.validators = custom_registry
      expect(subject.validators).to eq(custom_registry)
    end
  end

  describe "#task_breakpoints=" do
    let(:custom_breakpoints) { %w[failed error] }

    it "sets task_breakpoints to the provided value" do
      subject.task_breakpoints = custom_breakpoints
      expect(subject.task_breakpoints).to eq(custom_breakpoints)
    end
  end

  describe "#workflow_breakpoints=" do
    let(:custom_breakpoints) { %w[failed timeout] }

    it "sets workflow_breakpoints to the provided value" do
      subject.workflow_breakpoints = custom_breakpoints
      expect(subject.workflow_breakpoints).to eq(custom_breakpoints)
    end
  end

  describe "#logger=" do
    let(:custom_logger) { Logger.new($stderr) }

    it "sets logger to the provided value" do
      subject.logger = custom_logger
      expect(subject.logger).to eq(custom_logger)
    end
  end

  describe "#to_h" do
    it "returns a hash with all configuration attributes" do
      result = subject.to_h

      expect(result).to include(
        middlewares: subject.middlewares,
        callbacks: subject.callbacks,
        coercions: subject.coercions,
        validators: subject.validators,
        task_breakpoints: subject.task_breakpoints,
        workflow_breakpoints: subject.workflow_breakpoints,
        logger: subject.logger
      )
    end

    it "returns exactly 7 keys" do
      expect(subject.to_h.keys.size).to eq(7)
    end

    context "when attributes are modified" do
      let(:custom_breakpoints) { %w[custom] }
      let(:custom_logger) { Logger.new($stderr) }

      before do
        subject.task_breakpoints = custom_breakpoints
        subject.logger = custom_logger
      end

      it "returns the modified values" do
        result = subject.to_h

        expect(result[:task_breakpoints]).to eq(custom_breakpoints)
        expect(result[:logger]).to eq(custom_logger)
      end
    end
  end

  describe "DEFAULT_BREAKPOINTS" do
    it "is frozen" do
      expect(described_class::DEFAULT_BREAKPOINTS).to be_frozen
    end

    it "contains expected values" do
      expect(described_class::DEFAULT_BREAKPOINTS).to eq(%w[failed])
    end
  end
end

RSpec.describe CMDx do
  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(CMDx.configuration).to be_a(CMDx::Configuration)
    end

    it "returns the same instance on subsequent calls" do
      first_call = CMDx.configuration
      second_call = CMDx.configuration

      expect(first_call).to be(second_call)
    end

    context "when configuration is already set" do
      let(:custom_config) { CMDx::Configuration.new }

      before do
        CMDx.instance_variable_set(:@configuration, custom_config)
      end

      it "returns the existing configuration" do
        expect(CMDx.configuration).to be(custom_config)
      end
    end
  end

  describe ".configure" do
    it "yields the configuration object" do
      expect { |b| CMDx.configure(&b) }.to yield_with_args(CMDx::Configuration)
    end

    it "returns the configuration object" do
      result = CMDx.configure { |config| }
      expect(result).to be(CMDx.configuration)
    end

    it "allows modification of configuration within the block" do
      custom_breakpoints = %w[custom_failed]

      CMDx.configure do |config|
        config.task_breakpoints = custom_breakpoints
      end

      expect(CMDx.configuration.task_breakpoints).to eq(custom_breakpoints)
    end

    context "without a block" do
      it "raises ArgumentError" do
        expect { CMDx.configure }.to raise_error(ArgumentError, "block required")
      end
    end
  end

  describe ".reset_configuration!" do
    before do
      # Modify the configuration first
      CMDx.configure do |config|
        config.task_breakpoints = %w[custom]
        config.logger = Logger.new($stderr)
      end
    end

    it "creates a new Configuration instance" do
      original_config = CMDx.configuration
      CMDx.reset_configuration!

      expect(CMDx.configuration).not_to be(original_config)
      expect(CMDx.configuration).to be_a(CMDx::Configuration)
    end

    it "resets task_breakpoints to default values" do
      CMDx.reset_configuration!
      expect(CMDx.configuration.task_breakpoints).to eq(%w[failed])
    end

    it "resets workflow_breakpoints to default values" do
      CMDx.reset_configuration!
      expect(CMDx.configuration.workflow_breakpoints).to eq(%w[failed])
    end

    it "resets logger to default configuration" do
      CMDx.reset_configuration!
      logger = CMDx.configuration.logger

      expect(logger.progname).to eq("cmdx")
      expect(logger.formatter).to be_a(CMDx::LogFormatters::Line)
      expect(logger.level).to eq(Logger::INFO)
    end

    it "resets registries to their default state" do
      CMDx.reset_configuration!
      config = CMDx.configuration

      expect(config.middlewares.registry).to eq([])
      expect(config.callbacks.registry).to eq({})
      expect(config.coercions.registry).to include(:string, :integer, :boolean)
      expect(config.validators.registry).to include(:presence, :format, :inclusion)
    end
  end
end
