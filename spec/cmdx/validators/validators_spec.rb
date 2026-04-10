# frozen_string_literal: true

RSpec.describe "Validators" do
  describe CMDx::Validators::Presence do
    it "returns nil for present values" do
      expect(described_class.call("hello")).to be_nil
      expect(described_class.call(0)).to be_nil
      expect(described_class.call([1])).to be_nil
    end

    it "returns error for blank values" do
      expect(described_class.call(nil)).to be_a(String)
      expect(described_class.call("")).to be_a(String)
      expect(described_class.call([])).to be_a(String)
    end
  end

  describe CMDx::Validators::Absence do
    it "returns nil for blank values" do
      expect(described_class.call(nil)).to be_nil
      expect(described_class.call("")).to be_nil
    end

    it "returns error for present values" do
      expect(described_class.call("hi")).to be_a(String)
      expect(described_class.call(42)).to be_a(String)
    end
  end

  describe CMDx::Validators::Format do
    it "returns nil when format matches" do
      expect(described_class.call("test@example.com", format: /@/)).to be_nil
    end

    it "returns error when format mismatches" do
      expect(described_class.call("test", format: /@/)).to be_a(String)
    end
  end

  describe CMDx::Validators::Inclusion do
    it "validates inclusion in list" do
      expect(described_class.call("a", inclusion: %w[a b c])).to be_nil
      expect(described_class.call("d", inclusion: %w[a b c])).to be_a(String)
    end

    it "validates inclusion in range" do
      expect(described_class.call(5, inclusion: (1..10))).to be_nil
      expect(described_class.call(11, inclusion: (1..10))).to be_a(String)
    end
  end

  describe CMDx::Validators::Exclusion do
    it "validates exclusion from list" do
      expect(described_class.call("d", exclusion: %w[a b c])).to be_nil
      expect(described_class.call("a", exclusion: %w[a b c])).to be_a(String)
    end
  end

  describe CMDx::Validators::Length do
    it "validates exact length" do
      expect(described_class.call("abc", length: { is: 3 })).to be_nil
      expect(described_class.call("ab", length: { is: 3 })).to be_a(String)
    end

    it "validates min length" do
      expect(described_class.call("abc", length: { min: 2 })).to be_nil
      expect(described_class.call("a", length: { min: 2 })).to be_a(String)
    end

    it "validates max length" do
      expect(described_class.call("ab", length: { max: 3 })).to be_nil
      expect(described_class.call("abcd", length: { max: 3 })).to be_a(String)
    end
  end

  describe CMDx::Validators::Numeric do
    it "validates exact value" do
      expect(described_class.call(5, numeric: { is: 5 })).to be_nil
      expect(described_class.call(4, numeric: { is: 5 })).to be_a(String)
    end

    it "validates min value" do
      expect(described_class.call(5, numeric: { min: 1 })).to be_nil
      expect(described_class.call(0, numeric: { min: 1 })).to be_a(String)
    end

    it "validates within range" do
      expect(described_class.call(5, numeric: { within: 1..10 })).to be_nil
      expect(described_class.call(11, numeric: { within: 1..10 })).to be_a(String)
    end
  end
end
