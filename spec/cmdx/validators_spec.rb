# frozen_string_literal: true

RSpec.describe CMDx::Validators do
  describe ":presence" do
    it "passes for present value" do
      expect(described_class.validate(:presence, "hello", true)).to be_nil
    end

    it "fails for nil" do
      expect(described_class.validate(:presence, nil, true)).to be_a(String)
    end

    it "fails for empty string" do
      expect(described_class.validate(:presence, "", true)).to be_a(String)
    end

    it "fails for whitespace-only string" do
      expect(described_class.validate(:presence, "   ", true)).to be_a(String)
    end
  end

  describe ":absence" do
    it "passes for nil" do
      expect(described_class.validate(:absence, nil, true)).to be_nil
    end

    it "fails for present value" do
      expect(described_class.validate(:absence, "hello", true)).to be_a(String)
    end
  end

  describe ":format" do
    it "passes when matching pattern" do
      expect(described_class.validate(:format, "abc", { with: /\A[a-z]+\z/ })).to be_nil
    end

    it "fails when not matching pattern" do
      expect(described_class.validate(:format, "123", { with: /\A[a-z]+\z/ })).to be_a(String)
    end

    it "passes with shorthand regexp" do
      expect(described_class.validate(:format, "abc", /\A[a-z]+\z/)).to be_nil
    end
  end

  describe ":inclusion" do
    it "passes when included" do
      expect(described_class.validate(:inclusion, "a", { in: %w[a b c] })).to be_nil
    end

    it "fails when not included" do
      expect(described_class.validate(:inclusion, "z", { in: %w[a b c] })).to be_a(String)
    end

    it "works with ranges" do
      expect(described_class.validate(:inclusion, 5, { in: 1..10 })).to be_nil
      expect(described_class.validate(:inclusion, 15, { in: 1..10 })).to be_a(String)
    end
  end

  describe ":exclusion" do
    it "passes when not excluded" do
      expect(described_class.validate(:exclusion, "z", { in: %w[a b c] })).to be_nil
    end

    it "fails when excluded" do
      expect(described_class.validate(:exclusion, "a", { in: %w[a b c] })).to be_a(String)
    end
  end

  describe ":length" do
    it "validates minimum" do
      expect(described_class.validate(:length, "ab", { min: 3 })).to be_a(String)
      expect(described_class.validate(:length, "abc", { min: 3 })).to be_nil
    end

    it "validates maximum" do
      expect(described_class.validate(:length, "abcde", { max: 3 })).to be_a(String)
      expect(described_class.validate(:length, "abc", { max: 3 })).to be_nil
    end

    it "validates exact" do
      expect(described_class.validate(:length, "ab", { is: 3 })).to be_a(String)
      expect(described_class.validate(:length, "abc", { is: 3 })).to be_nil
    end

    it "validates range" do
      expect(described_class.validate(:length, "a", { within: 2..5 })).to be_a(String)
      expect(described_class.validate(:length, "abc", { within: 2..5 })).to be_nil
    end
  end

  describe ":numeric" do
    it "validates min" do
      expect(described_class.validate(:numeric, 5, { min: 10 })).to be_a(String)
      expect(described_class.validate(:numeric, 15, { min: 10 })).to be_nil
    end

    it "validates max" do
      expect(described_class.validate(:numeric, 15, { max: 10 })).to be_a(String)
      expect(described_class.validate(:numeric, 5, { max: 10 })).to be_nil
    end

    it "validates range" do
      expect(described_class.validate(:numeric, 15, { within: 1..10 })).to be_a(String)
      expect(described_class.validate(:numeric, 5, { within: 1..10 })).to be_nil
    end
  end

  describe "allow_nil" do
    it "skips validation when value is nil and allow_nil is true" do
      expect(described_class.validate(:presence, nil, { allow_nil: true })).to be_nil
    end
  end
end
