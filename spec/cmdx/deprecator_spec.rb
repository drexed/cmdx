# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Deprecator do
  let(:task_class) do
    Class.new(CMDx::Task) do
      def work; end
    end
  end

  describe ".check!" do
    it "raises DeprecationError for :restrict mode" do
      task_class.settings { |s| s.deprecate = { mode: :restrict, message: "gone" } }
      expect { described_class.check!(task_class) }.to raise_error(CMDx::DeprecationError, /gone/)
    end

    it "warns for :warn mode" do
      task_class.settings { |s| s.deprecate = { mode: :warn, message: "soon" } }
      expect { described_class.check!(task_class) }.to output(/DEPRECATED.*soon/).to_stderr
    end

    it "does nothing when no deprecation configured" do
      expect { described_class.check!(task_class) }.not_to raise_error
      expect { described_class.check!(task_class) }.not_to output.to_stderr
    end
  end
end
