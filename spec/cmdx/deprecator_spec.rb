# frozen_string_literal: true

RSpec.describe CMDx::Deprecator do
  let(:task_class) { Class.new(CMDx::Task) { def self.name = "OldTask" } }

  describe ".check!" do
    it "raises on :restrict mode" do
      expect do
        described_class.check!(task_class, { mode: :restrict })
      end.to raise_error(CMDx::DeprecationError)
    end

    it "warns on :warn mode" do
      expect do
        described_class.check!(task_class, { mode: :warn })
      end.to output(/DEPRECATION/).to_stderr
    end

    it "includes alternative in message" do
      expect do
        described_class.check!(task_class, { mode: :restrict, alternative: "NewTask" })
      end.to raise_error(CMDx::DeprecationError, /NewTask/)
    end
  end
end
