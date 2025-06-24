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
      result = described_class.configure { |c| c.task_halt = "failed" }
      expect(result).to be_instance_of(CMDx::Configuration)
    end

    it "allows setting configuration attributes" do
      described_class.configure do |config|
        config.task_halt = %i[failed skipped]
      end

      config = described_class.configuration
      expect(config.task_halt).to eq(%i[failed skipped])
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
      described_class.configure { |c| c.task_halt = "failed" }
      described_class.configure { |c| c.batch_halt = "skipped" }

      config = described_class.configuration
      expect(config.task_halt).to eq("failed")
      expect(config.batch_halt).to eq("skipped")
    end

    it "is thread-safe" do
      results = []
      threads = []

      10.times do |i|
        threads << Thread.new do
          described_class.configure { |c| c.task_halt = "test_#{i}" }
          results << described_class.configuration.task_halt
        end
      end

      threads.each(&:join)

      # The final value should be one of the set values
      expect((0..9).map { |i| "test_#{i}" }).to include(described_class.configuration.task_halt)
    end
  end

  describe ".reset_configuration!" do
    it "returns a new Configuration instance with default values" do
      # Modify configuration
      described_class.configure do |config|
        config.task_halt = [:custom]
      end

      original_config = described_class.configuration
      expect(original_config.task_halt).to eq([:custom])

      # Reset configuration
      new_config = described_class.reset_configuration!

      expect(new_config).to be_instance_of(CMDx::Configuration)
      expect(new_config).not_to be(original_config)
      expect(new_config.task_halt).to eq("failed")
    end

    it "subsequent calls to configuration return the new instance" do
      described_class.configure { |c| c.task_halt = "custom" }
      described_class.reset_configuration!

      config = described_class.configuration
      expect(config.task_halt).to eq("failed")
    end

    it "is thread-safe" do
      results = []
      threads = []

      # Set initial configuration
      described_class.configure { |c| c.task_halt = "custom" }

      10.times do
        threads << Thread.new do
          described_class.reset_configuration!
          results << described_class.configuration.task_halt
        end
      end

      threads.each(&:join)

      # All results should be "failed" (default value)
      expect(results).to all(eq("failed"))
    end
  end

  describe "configuration integration" do
    after { described_class.reset_configuration! }

    it "configuration is used by task settings" do
      described_class.configure do |config|
        config.task_halt = "custom"
      end

      config_hash = described_class.configuration.to_h

      expect(config_hash[:task_halt]).to eq("custom")
    end

    it "supports complex configuration scenarios" do
      custom_logger = Logger.new(nil)

      described_class.configure do |config|
        config.logger = custom_logger
        config.task_halt = ["failed"]
        config.batch_halt = %w[failed skipped]
      end

      config = described_class.configuration

      expect(config.logger).to eq(custom_logger)
      expect(config.task_halt).to eq(["failed"])
      expect(config.batch_halt).to eq(%w[failed skipped])
    end
  end
end
