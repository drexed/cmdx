# frozen_string_literal: true

RSpec.describe CMDx::Deprecators::Warn do
  describe ".call" do
    let(:task) { Class.new.new }

    it "writes to stderr via Kernel.warn" do
      expect { described_class.call(task) }
        .to output(/DEPRECATED: migrate/).to_stderr
    end
  end
end
