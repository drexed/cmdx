# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Attribute do
  describe "#initialize" do
    it "exposes name, type, required, default, as, from, derive, transform, options" do
      derive = ->(v) { v }
      transform = ->(v) { v }
      attr = described_class.new(
        :email,
        :string,
        required: false,
        default: "x@y.z",
        as: :mail,
        from: :raw_email,
        derive: derive,
        transform: transform,
        foo: :bar
      )

      expect(attr.name).to eq(:email)
      expect(attr.type).to eq(:string)
      expect(attr.required).to be(false)
      expect(attr.default).to eq("x@y.z")
      expect(attr.as).to eq(:mail)
      expect(attr.from).to eq(:raw_email)
      expect(attr.derive).to equal(derive)
      expect(attr.transform).to equal(transform)
      expect(attr.options[:foo]).to eq(:bar)
    end

    it "defaults required to true" do
      expect(described_class.new(:id).required).to be(true)
    end

    it "symbolizes name" do
      expect(described_class.new("token").name).to eq(:token)
    end
  end

  describe "#allocation_name" do
    it "returns #as when set" do
      attr = described_class.new(:user_id, as: :id)
      expect(attr.allocation_name).to eq(:id)
    end

    it "returns #name when :as is omitted" do
      attr = described_class.new(:user_id)
      expect(attr.allocation_name).to eq(:user_id)
    end
  end

  describe "#required?, #optional?, #typed?, #has_default?" do
    it "reflects required and type" do
      req = described_class.new(:a, :integer)
      expect(req).to be_required
      expect(req).not_to be_optional
      expect(req).to be_typed

      opt = described_class.new(:b, required: false)
      expect(opt).not_to be_required
      expect(opt).to be_optional
      expect(opt).not_to be_typed
    end

    it "reflects default presence" do
      expect(described_class.new(:a)).not_to be_has_default
      expect(described_class.new(:a, default: 0)).to be_has_default
    end
  end

  describe "#validations" do
    it "auto-adds :presence when required and :presence not given" do
      attr = described_class.new(:name, :string)
      expect(attr.validations[:presence]).to be(true)
    end

    it "does not auto-add :presence when optional" do
      attr = described_class.new(:name, :string, required: false)
      expect(attr.validations).not_to have_key(:presence)
    end

    it "does not overwrite explicit :presence" do
      attr = described_class.new(:name, :string, presence: false)
      expect(attr.validations[:presence]).to be(false)
    end

    it "extracts validator options from declaration (e.g. length)" do
      attr = described_class.new(:code, :string, required: false, length: { min: 3 })
      expect(attr.validations[:length]).to eq({ min: 3 })
      expect(attr.validations).not_to have_key(:presence)
    end

    it "extracts multiple built-in validators" do
      attr = described_class.new(
        :x,
        :integer,
        required: false,
        format: { with: /\A\d+\z/ },
        inclusion: { of: [1, 2, 3] }
      )
      expect(attr.validations[:format]).to eq({ with: /\A\d+\z/ })
      expect(attr.validations[:inclusion]).to eq({ of: [1, 2, 3] })
    end
  end

  describe "#to_h" do
    it "returns a serializable summary" do
      attr = described_class.new(:email, :string, as: :mail, from: :raw, required: false, default: nil)
      expect(attr.to_h).to eq(
        name: :email,
        type: :string,
        required: false,
        default: nil,
        as: :mail,
        from: :raw,
        validations: {}
      )
    end
  end
end
