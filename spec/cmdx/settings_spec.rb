# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Settings do
  describe "#build" do
    it "returns self when new_options is empty" do
      settings = described_class.new(a: 1)
      expect(settings.build({})).to be(settings)
    end

    it "returns a new instance with merged options" do
      settings = described_class.new(a: 1, b: 2)
      merged = settings.build(b: 99, c: 3)

      expect(merged).not_to be(settings)
      expect(merged.instance_variable_get(:@options)).to eq(a: 1, b: 99, c: 3)
    end
  end

  describe "configuration fallbacks" do
    let(:custom_logger) { Logger.new(nil) }
    let(:custom_formatter) { ->(sev, _time, _prog, msg) { "#{sev} #{msg}" } }
    let(:custom_cleaner) { ->(bt) { bt } }

    before do
      CMDx.configuration.logger = custom_logger
      CMDx.configuration.log_formatter = custom_formatter
      CMDx.configuration.log_level = Logger::DEBUG
      CMDx.configuration.backtrace_cleaner = custom_cleaner
    end

    it "logger falls back to the global configuration" do
      expect(described_class.new.logger).to be(custom_logger)
    end

    it "log_formatter falls back to the global configuration" do
      expect(described_class.new.log_formatter).to be(custom_formatter)
    end

    it "log_level falls back to the global configuration" do
      expect(described_class.new.log_level).to eq(Logger::DEBUG)
    end

    it "backtrace_cleaner falls back to the global configuration" do
      expect(described_class.new.backtrace_cleaner).to be(custom_cleaner)
    end
  end

  describe "option overrides" do
    let(:local_logger) { Logger.new(nil) }

    it "logger prefers the local option over the global default" do
      expect(described_class.new(logger: local_logger).logger).to be(local_logger)
    end

    it "log_formatter prefers the local option" do
      fmt = ->(*_) { "" }
      expect(described_class.new(log_formatter: fmt).log_formatter).to be(fmt)
    end

    it "log_level prefers the local option" do
      expect(described_class.new(log_level: Logger::ERROR).log_level).to eq(Logger::ERROR)
    end

    it "backtrace_cleaner prefers the local option" do
      cleaner = ->(bt) { bt }
      expect(described_class.new(backtrace_cleaner: cleaner).backtrace_cleaner).to be(cleaner)
    end
  end

  describe "#tags" do
    it "returns an empty array by default" do
      expect(described_class.new.tags).to eq([])
    end

    it "returns the configured tags" do
      expect(described_class.new(tags: %w[a b]).tags).to eq(%w[a b])
    end

    it "returns a fresh array on each call so callers can mutate without leaking" do
      settings = described_class.new(tags: %w[a])

      first = settings.tags
      first << "mutated"

      expect(settings.tags).to eq(%w[a])
      expect(first).not_to be_frozen
    end

    it "default empty array is mutable and unique per call" do
      settings = described_class.new

      a = settings.tags
      b = settings.tags
      a << :x

      expect(b).to eq([])
      expect(a).not_to be(b)
    end
  end

  describe "immutability" do
    it "freezes the internal options hash" do
      settings = described_class.new(a: 1)
      expect(settings.instance_variable_get(:@options)).to be_frozen
    end
  end
end
