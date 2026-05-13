# frozen_string_literal: true

RSpec.describe CMDx::Validators::Format do
  describe ".call" do
    it "passes when :with matches" do
      expect(described_class.call("abc", with: /^a/)).to be_nil
    end

    it "fails when :with does not match" do
      expect(described_class.call("xyz", with: /^a/)).to be_a(CMDx::Validators::Failure)
    end

    it "passes when :without does not match" do
      expect(described_class.call("abc", without: /z/)).to be_nil
    end

    it "fails when :without matches" do
      expect(described_class.call("xyz", without: /z/)).to be_a(CMDx::Validators::Failure)
    end

    it "combines :with and :without" do
      expect(described_class.call("abc", with: /^a/, without: /z/)).to be_nil
      expect(described_class.call("abz", with: /^a/, without: /z/)).to be_a(CMDx::Validators::Failure)
    end

    it "handles nil values gracefully" do
      expect(described_class.call(nil, with: /a/)).to be_a(CMDx::Validators::Failure)
    end

    it "raises without any option" do
      expect { described_class.call("x") }.to raise_error(ArgumentError, %r{:with and/or :without})
    end

    it "uses :message when supplied" do
      f = described_class.call("x", with: /y/, message: "bad format")
      expect(f.message).to eq("bad format")
    end
  end
end
