# frozen_string_literal: true

RSpec.describe CMDx::ErrorDetail do
  subject(:detail) { described_class.new(:email, "is invalid", :format) }

  it "stores attribute, message, and code" do
    expect(detail.attribute).to eq(:email)
    expect(detail.message).to eq("is invalid")
    expect(detail.code).to eq(:format)
  end

  describe "#full_message" do
    it "formats attribute and message" do
      expect(detail.full_message).to eq("email is invalid")
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      expect(detail.to_h).to eq(attribute: :email, message: "is invalid", code: :format)
    end

    it "omits code when nil" do
      d = described_class.new(:name, "required")
      expect(d.to_h).to eq(attribute: :name, message: "required")
    end
  end
end
