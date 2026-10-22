# frozen_string_literal: true

RSpec.describe CMDx::Deprecators::Error do
  describe ".call" do
    let(:task) { Class.new.new }

    it "raises DeprecationError" do
      expect { described_class.call(task) }
        .to raise_error(CMDx::DeprecationError, /is deprecated and prohibited from execution/)
    end
  end
end
