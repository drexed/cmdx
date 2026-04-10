# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx do
  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(CMDx::Configuration)
    end

    it "returns the same instance on subsequent calls" do
      first = described_class.configuration
      second = described_class.configuration
      expect(first.object_id).to eq(second.object_id)
    end
  end

  describe ".configure" do
    it "yields the configuration object" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(CMDx::Configuration)
    end

    it "allows changing task breakpoints" do
      described_class.configure do |c|
        c.task_breakpoints = %i[failed skipped]
      end

      expect(described_class.configuration.task_breakpoints).to eq(%i[failed skipped])
    end
  end

  describe ".reset_configuration!" do
    it "replaces the configuration singleton" do
      before_id = described_class.configuration.object_id
      described_class.reset_configuration!
      expect(described_class.configuration.object_id).not_to eq(before_id)
    end
  end
end
