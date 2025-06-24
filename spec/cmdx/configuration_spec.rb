# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Configuration do
  describe ".new" do
    subject(:config) { described_class.new }

    it "sets default logger with Line formatter" do
      expect(config.logger).to be_a(Logger)
      expect(config.logger.instance_variable_get(:@formatter)).to be_instance_of(CMDx::LogFormatters::Line)
    end

    it "sets default task_halt to 'failed'" do
      expect(config.task_halt).to eq("failed")
    end

    it "sets default batch_halt to 'failed'" do
      expect(config.batch_halt).to eq("failed")
    end
  end

  describe "#to_h" do
    subject(:config) { described_class.new }

    it "returns a hash with all configuration attributes" do
      result = config.to_h

      expect(result).to be_a(Hash)
      expect(result.keys).to match_array(%i[logger task_halt batch_halt])
    end

    it "returns current attribute values" do
      config.task_halt = %i[failed skipped]

      result = config.to_h

      expect(result[:task_halt]).to eq(%i[failed skipped])
      expect(result[:logger]).to be_a(Logger)
    end
  end

  describe "attribute accessors" do
    subject(:config) { described_class.new }

    it "allows reading and writing logger" do
      new_logger = Logger.new(nil)
      config.logger = new_logger
      expect(config.logger).to eq(new_logger)
    end

    it "allows reading and writing task_halt" do
      config.task_halt = %i[failed skipped]
      expect(config.task_halt).to eq(%i[failed skipped])
    end

    it "allows reading and writing batch_halt" do
      config.batch_halt = "skipped"
      expect(config.batch_halt).to eq("skipped")
    end
  end
end
