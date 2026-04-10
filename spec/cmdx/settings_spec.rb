# frozen_string_literal: true

RSpec.describe CMDx::Settings do
  subject(:settings) { described_class.new }

  describe "#merge!" do
    it "stores overrides" do
      settings.merge!(retries: 3, tags: ["important"])
      expect(settings[:retries]).to eq(3)
      expect(settings[:tags]).to eq(["important"])
    end

    it "last-write-wins" do
      settings.merge!(retries: 1)
      settings.merge!(retries: 5)
      expect(settings[:retries]).to eq(5)
    end
  end

  describe "#[]" do
    it "falls back to global config" do
      CMDx.configuration.dump_context = true
      expect(settings[:dump_context]).to be(true)
    end

    it "overrides win over global" do
      CMDx.configuration.dump_context = true
      settings.merge!(dump_context: false)
      expect(settings[:dump_context]).to be(false)
    end
  end

  describe "parent chain" do
    it "inherits from parent settings" do
      parent = described_class.new
      parent.merge!(retries: 3)

      child = described_class.new(parent: parent)
      expect(child[:retries]).to eq(3)
    end

    it "child override wins over parent" do
      parent = described_class.new
      parent.merge!(retries: 3)

      child = described_class.new(parent: parent)
      child.merge!(retries: 1)
      expect(child[:retries]).to eq(1)
    end
  end

  describe "convenience methods" do
    it "provides defaults for retries" do
      expect(settings.retries).to eq(0)
    end

    it "provides defaults for tags" do
      expect(settings.tags).to eq([])
    end

    it "provides defaults for log_level" do
      expect(settings.log_level).to eq(:info)
    end
  end
end
