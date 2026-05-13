# frozen_string_literal: true

RSpec.describe CMDx::Coercions::Boolean do
  describe ".call" do
    %w[true yes on y 1 t True YES ON].each do |input|
      it "is true for #{input.inspect}" do
        expect(described_class.call(input)).to be(true)
      end
    end

    %w[false no off n 0 f FALSE No OFF].each do |input|
      it "is false for #{input.inspect}" do
        expect(described_class.call(input)).to be(false)
      end
    end

    it "handles booleans via their string form" do
      expect(described_class.call(true)).to be(true)
      expect(described_class.call(false)).to be(false)
    end

    it "is false for nil" do
      expect(described_class.call(nil)).to be(false)
    end

    it "returns a Failure for unrecognized strings" do
      expect(described_class.call("maybe")).to be_a(CMDx::Coercions::Failure)
    end
  end
end
