# frozen_string_literal: true

RSpec.describe CMDx::LoggerProxy do
  let(:task_class) { create_task_class }
  let(:task) { task_class.new }
  let(:base_logger) { task_class.settings.logger }

  describe ".logger" do
    it "returns the settings logger when level and formatter already match" do
      base_logger.level = Logger::INFO
      base_logger.formatter = proc { |*| "x" }
      task_class.settings(log_level: base_logger.level, log_formatter: base_logger.formatter)

      expect(described_class.logger(task)).to be(base_logger)
    end

    it "returns a duped logger with an adjusted level" do
      task_class.settings(log_level: Logger::FATAL)

      logger = described_class.logger(task)

      expect(logger).not_to be(base_logger)
      expect(logger.level).to eq(Logger::FATAL)
    end

    it "returns a duped logger with an adjusted formatter" do
      custom_formatter = proc { |_, _, _, msg| "[X] #{msg}\n" }
      task_class.settings(log_formatter: custom_formatter)

      logger = described_class.logger(task)

      expect(logger).not_to be(base_logger)
      expect(logger.formatter).to be(custom_formatter)
    end

    it "returns a duped logger when both level and formatter differ" do
      custom_formatter = proc { |_, _, _, msg| "[Y] #{msg}\n" }
      task_class.settings(log_level: Logger::DEBUG, log_formatter: custom_formatter)

      logger = described_class.logger(task)

      expect(logger.level).to eq(Logger::DEBUG)
      expect(logger.formatter).to be(custom_formatter)
    end

    it "compares formatters by identity, not by value" do
      shared_formatter = proc { |*| "x" }
      base_logger.formatter = shared_formatter
      task_class.settings(log_level: base_logger.level, log_formatter: shared_formatter)

      expect(described_class.logger(task)).to be(base_logger)
    end

    it "dups when a formatter with a custom == that returns true is supplied" do
      weird = Class.new do
        def call(*) = ""
        def ==(_other) = true
      end.new

      task_class.settings(log_formatter: weird)

      logger = described_class.logger(task)
      expect(logger).not_to be(base_logger)
      expect(logger.formatter).to be(weird)
    end

    it "does not mutate the settings logger" do
      original_level = base_logger.level
      original_formatter = base_logger.formatter
      task_class.settings(log_level: Logger::DEBUG, log_formatter: proc { |*| "x" })

      described_class.logger(task)

      expect(base_logger.level).to eq(original_level)
      expect(base_logger.formatter).to eq(original_formatter)
    end
  end
end
