# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx do
  describe ".configuration" do
    after { described_class.reset_configuration! }

    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_instance_of(CMDx::Configuration)
    end

    it "returns the same instance on subsequent calls" do
      config1 = described_class.configuration
      config2 = described_class.configuration
      expect(config1).to be(config2)
    end

    it "is thread-safe" do
      configurations = []
      threads = []

      10.times do
        threads << Thread.new do
          configurations << described_class.configuration
        end
      end

      threads.each(&:join)

      expect(configurations.uniq.size).to eq(1)
    end
  end

  describe ".configure" do
    after { described_class.reset_configuration! }

    it "yields the configuration instance" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(CMDx::Configuration)
    end

    it "returns the configuration instance" do
      result = described_class.configure { |c| c.task_timeout = 30 }
      expect(result).to be_instance_of(CMDx::Configuration)
    end

    it "allows setting configuration attributes" do
      described_class.configure do |config|
        config.task_timeout = 45
        config.task_halt = %i[failed skipped]
        config.batch_timeout = 300
      end

      config = described_class.configuration
      expect(config.task_timeout).to eq(45)
      expect(config.task_halt).to eq(%i[failed skipped])
      expect(config.batch_timeout).to eq(300)
    end

    it "allows setting custom logger" do
      custom_logger = Logger.new(nil)

      described_class.configure do |config|
        config.logger = custom_logger
      end

      expect(described_class.configuration.logger).to eq(custom_logger)
    end

    it "raises ArgumentError when no block is given" do
      expect { described_class.configure }.to raise_error(ArgumentError, "block required")
    end

    it "preserves changes across multiple configure calls" do
      described_class.configure { |c| c.task_timeout = 30 }
      described_class.configure { |c| c.batch_timeout = 60 }

      config = described_class.configuration
      expect(config.task_timeout).to eq(30)
      expect(config.batch_timeout).to eq(60)
    end

    it "is thread-safe" do
      results = []
      threads = []

      10.times do |i|
        threads << Thread.new do
          described_class.configure { |c| c.task_timeout = i * 10 }
          results << described_class.configuration.task_timeout
        end
      end

      threads.each(&:join)

      # The final value should be one of the set values
      expect((0..9).map { |i| i * 10 }).to include(described_class.configuration.task_timeout)
    end
  end

  describe ".reset_configuration!" do
    it "returns a new Configuration instance with default values" do
      # Modify configuration
      described_class.configure do |config|
        config.task_timeout = 99
        config.task_halt = [:custom]
      end

      original_config = described_class.configuration
      expect(original_config.task_timeout).to eq(99)

      # Reset configuration
      new_config = described_class.reset_configuration!

      expect(new_config).to be_instance_of(CMDx::Configuration)
      expect(new_config).not_to be(original_config)
      expect(new_config.task_timeout).to be_nil
      expect(new_config.task_halt).to eq("failed")
    end

    it "subsequent calls to configuration return the new instance" do
      described_class.configure { |c| c.task_timeout = 123 }
      described_class.reset_configuration!

      config = described_class.configuration
      expect(config.task_timeout).to be_nil
    end

    it "is thread-safe" do
      results = []
      threads = []

      # Set initial configuration
      described_class.configure { |c| c.task_timeout = 100 }

      10.times do
        threads << Thread.new do
          described_class.reset_configuration!
          results << described_class.configuration.task_timeout
        end
      end

      threads.each(&:join)

      # All results should be nil (default value)
      expect(results).to all(be_nil)
    end
  end

  describe "configuration integration" do
    after { described_class.reset_configuration! }

    it "configuration is used by task settings" do
      described_class.configure do |config|
        config.task_timeout = 42
        config.task_halt = "custom"
      end

      config_hash = described_class.configuration.to_h

      expect(config_hash[:task_timeout]).to eq(42)
      expect(config_hash[:task_halt]).to eq("custom")
    end

    it "supports complex configuration scenarios" do
      custom_logger = Logger.new(nil)

      described_class.configure do |config|
        config.logger = custom_logger
        config.task_timeout = ENV.fetch("TASK_TIMEOUT", 30).to_i
        config.batch_timeout = 300
        config.task_halt = ["failed"]
        config.batch_halt = %w[failed skipped]
      end

      config = described_class.configuration

      expect(config.logger).to eq(custom_logger)
      expect(config.task_timeout).to eq(30)
      expect(config.batch_timeout).to eq(300)
      expect(config.task_halt).to eq(["failed"])
      expect(config.batch_halt).to eq(%w[failed skipped])
    end
  end
end
