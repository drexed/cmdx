# frozen_string_literal: true

RSpec.describe CMDx::ValueResolver do
  let(:coercions) { CMDx::Definition.root.coercions }
  let(:validators) { CMDx::Definition.root.validators }
  let(:errors) { CMDx::Errors.new }

  describe ".resolve_all" do
    it "resolves attributes from context" do
      attrs = [CMDx::Attribute.new(:name, { type: :string, required: true })]
      context = CMDx::Context.new(name: "Juan")
      result = described_class.resolve_all(attrs, context, coercions:, validators:, errors:)
      expect(result[:name]).to eq("Juan")
    end

    it "applies defaults" do
      attrs = [CMDx::Attribute.new(:color, { type: :string, default: "blue" })]
      context = CMDx::Context.new
      result = described_class.resolve_all(attrs, context, coercions:, validators:, errors:)
      expect(result[:color]).to eq("blue")
    end

    it "coerces values" do
      attrs = [CMDx::Attribute.new(:age, { type: :integer })]
      context = CMDx::Context.new(age: "25")
      result = described_class.resolve_all(attrs, context, coercions:, validators:, errors:)
      expect(result[:age]).to eq(25)
    end

    it "validates and adds errors" do
      attrs = [CMDx::Attribute.new(:email, { type: :string, required: true })]
      context = CMDx::Context.new(email: "")
      described_class.resolve_all(attrs, context, coercions:, validators:, errors:)
      expect(errors.any?).to be true
    end

    it "handles nested children" do
      child = CMDx::Attribute.new(:street, { type: :string, required: true })
      parent = CMDx::Attribute.new(:address, { type: :hash, required: true }, [child])
      context = CMDx::Context.new(address: { street: "Main St" })
      result = described_class.resolve_all([parent], context, coercions:, validators:, errors:)
      expect(result[:address]).to eq(street: "Main St")
    end

    it "validates nested children with namespaced errors" do
      child = CMDx::Attribute.new(:street, { type: :string, required: true })
      parent = CMDx::Attribute.new(:address, { type: :hash, required: true }, [child])
      context = CMDx::Context.new(address: { street: "" })
      described_class.resolve_all([parent], context, coercions:, validators:, errors:)
      expect(errors[:"address.street"]).not_to be_empty
    end
  end
end
