# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Configuration do
  subject(:configuration) { described_class.new }

  describe "#initialize" do
    it "sets default logger with Line formatter" do
      expect(configuration.logger).to be_a(Logger)
      expect(configuration.logger.formatter).to be_a(CMDx::LogFormatters::Line)
    end

    it "initializes empty registries" do
      expect(configuration.middlewares).to be_a(CMDx::MiddlewareRegistry)
      expect(configuration.callbacks).to be_a(CMDx::CallbackRegistry)
      expect(configuration.coercions).to be_a(CMDx::CoercionRegistry)
      expect(configuration.validators).to be_a(CMDx::ValidatorRegistry)
    end

    it "sets default halt conditions" do
      expect(configuration.task_halt).to eq("failed")
      expect(configuration.workflow_halt).to eq("failed")
    end
  end

  describe "#to_h" do
    let(:expected_keys) do
      %i[logger middlewares callbacks coercions validators task_halt workflow_halt]
    end

    it "returns hash with all configuration values" do
      result = configuration.to_h

      expect(result.keys).to match_array(expected_keys)
    end

    it "includes actual configuration objects" do
      result = configuration.to_h

      expect(result[:logger]).to eq(configuration.logger)
      expect(result[:middlewares]).to eq(configuration.middlewares)
      expect(result[:callbacks]).to eq(configuration.callbacks)
      expect(result[:coercions]).to eq(configuration.coercions)
      expect(result[:validators]).to eq(configuration.validators)
      expect(result[:task_halt]).to eq(configuration.task_halt)
      expect(result[:workflow_halt]).to eq(configuration.workflow_halt)
    end
  end

  describe "attribute accessors" do
    describe "#logger" do
      it "allows setting custom logger" do
        custom_logger = Logger.new(StringIO.new)
        configuration.logger = custom_logger

        expect(configuration.logger).to eq(custom_logger)
      end
    end

    describe "#middlewares" do
      it "allows setting custom middleware registry" do
        custom_registry = CMDx::MiddlewareRegistry.new
        configuration.middlewares = custom_registry

        expect(configuration.middlewares).to eq(custom_registry)
      end
    end

    describe "#callbacks" do
      it "allows setting custom callback registry" do
        custom_registry = CMDx::CallbackRegistry.new
        configuration.callbacks = custom_registry

        expect(configuration.callbacks).to eq(custom_registry)
      end
    end

    describe "#coercions" do
      it "allows setting custom coercion registry" do
        custom_registry = CMDx::CoercionRegistry.new
        configuration.coercions = custom_registry

        expect(configuration.coercions).to eq(custom_registry)
      end
    end

    describe "#validators" do
      it "allows setting custom validator registry" do
        custom_registry = CMDx::ValidatorRegistry.new
        configuration.validators = custom_registry

        expect(configuration.validators).to eq(custom_registry)
      end
    end

    describe "#task_halt" do
      it "allows setting string halt condition" do
        configuration.task_halt = "error"

        expect(configuration.task_halt).to eq("error")
      end

      it "allows setting array halt conditions" do
        halt_conditions = %w[failed error skipped]
        configuration.task_halt = halt_conditions

        expect(configuration.task_halt).to eq(halt_conditions)
      end
    end

    describe "#workflow_halt" do
      it "allows setting string halt condition" do
        configuration.workflow_halt = "error"

        expect(configuration.workflow_halt).to eq("error")
      end

      it "allows setting array halt conditions" do
        halt_conditions = %w[failed error]
        configuration.workflow_halt = halt_conditions

        expect(configuration.workflow_halt).to eq(halt_conditions)
      end
    end
  end

  describe "DEFAULT_HALT constant" do
    it "is set to 'failed'" do
      expect(described_class::DEFAULT_HALT).to eq("failed")
    end
  end
end
