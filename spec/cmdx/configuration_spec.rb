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

    it "initializes empty hook registry" do
      expect(configuration.hooks).to be_a(CMDx::HookRegistry)
    end

    it "sets default halt values" do
      expect(configuration.task_halt).to eq("failed")
      expect(configuration.batch_halt).to eq("failed")
    end
  end

  describe "#to_h" do
    it "returns a hash with all configuration attributes" do
      hash = configuration.to_h

      expect(hash).to be_a(Hash)
      expect(hash.keys).to contain_exactly(:logger, :middlewares, :hooks, :task_halt, :batch_halt)
    end

    it "returns the actual attribute values" do
      hash = configuration.to_h

      expect(hash[:logger]).to be(configuration.logger)
      expect(hash[:middlewares]).to be(configuration.middlewares)
      expect(hash[:hooks]).to be(configuration.hooks)
      expect(hash[:task_halt]).to eq(configuration.task_halt)
      expect(hash[:batch_halt]).to eq(configuration.batch_halt)
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
    let(:custom_hooks) { CMDx::HookRegistry.new }

    it "allows reading and writing logger" do
      configuration.logger = custom_logger

      expect(configuration.logger).to be(custom_logger)
    end

    it "allows reading and writing middlewares" do
      configuration.middlewares = custom_middlewares

      expect(configuration.middlewares).to be(custom_middlewares)
    end

    it "allows reading and writing hooks" do
      configuration.hooks = custom_hooks

      expect(configuration.hooks).to be(custom_hooks)
    end

    it "allows reading and writing task_halt" do
      configuration.task_halt = %w[failed skipped]

      expect(configuration.task_halt).to eq(%w[failed skipped])
    end

    it "allows reading and writing batch_halt" do
      configuration.batch_halt = %w[failed error]

      expect(configuration.batch_halt).to eq(%w[failed error])
    end
  end
end
