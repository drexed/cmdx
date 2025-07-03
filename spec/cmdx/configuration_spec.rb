# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Configuration do
  subject(:configuration) { described_class.new }

  describe "#initialize" do
    it "sets default logger with Line formatter" do
      expect(configuration.logger).to be_a(Logger)
      expect(configuration.logger.formatter).to be_a(CMDx::LogFormatters::Line)
    end

    it "initializes empty middleware registry" do
      expect(configuration.middlewares).to be_a(CMDx::MiddlewareRegistry)
    end

    it "initializes empty callback registry" do
      expect(configuration.callbacks).to be_a(CMDx::CallbackRegistry)
    end

    it "sets default halt values" do
      expect(configuration.task_halt).to eq("failed")
      expect(configuration.workflow_halt).to eq("failed")
    end
  end

  describe "#to_h" do
    it "returns a hash with all configuration attributes" do
      hash = configuration.to_h

      expect(hash).to be_a(Hash)
      expect(hash.keys).to contain_exactly(:logger, :middlewares, :callbacks, :task_halt, :workflow_halt)
    end

    it "returns the actual attribute values" do
      hash = configuration.to_h

      expect(hash[:logger]).to be(configuration.logger)
      expect(hash[:middlewares]).to be(configuration.middlewares)
      expect(hash[:callbacks]).to be(configuration.callbacks)
      expect(hash[:task_halt]).to eq(configuration.task_halt)
      expect(hash[:workflow_halt]).to eq(configuration.workflow_halt)
    end

    it "reflects changes to configuration attributes" do
      custom_logger = Logger.new(StringIO.new)
      configuration.logger = custom_logger
      configuration.task_halt = %w[failed skipped]

      hash = configuration.to_h

      expect(hash[:logger]).to be(custom_logger)
      expect(hash[:task_halt]).to eq(%w[failed skipped])
    end
  end

  describe "attribute accessors" do
    let(:custom_logger) { Logger.new(StringIO.new) }
    let(:custom_middlewares) { CMDx::MiddlewareRegistry.new }
    let(:custom_callbacks) { CMDx::CallbackRegistry.new }

    it "allows reading and writing logger" do
      configuration.logger = custom_logger

      expect(configuration.logger).to be(custom_logger)
    end

    it "allows reading and writing middlewares" do
      configuration.middlewares = custom_middlewares

      expect(configuration.middlewares).to be(custom_middlewares)
    end

    it "allows reading and writing callbacks" do
      configuration.callbacks = custom_callbacks

      expect(configuration.callbacks).to be(custom_callbacks)
    end

    it "allows reading and writing task_halt" do
      configuration.task_halt = %w[failed skipped]

      expect(configuration.task_halt).to eq(%w[failed skipped])
    end

    it "allows reading and writing workflow_halt" do
      configuration.workflow_halt = %w[failed error]

      expect(configuration.workflow_halt).to eq(%w[failed error])
    end
  end
end
