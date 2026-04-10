# frozen_string_literal: true

RSpec.describe CMDx::Attribute do
  describe "basic construction" do
    subject(:attr) { described_class.new(:email, { type: :string, required: true, presence: true }) }

    it "captures name and type" do
      expect(attr.name).to eq(:email)
      expect(attr.type_keys).to eq([:string])
      expect(attr).to be_required
      expect(attr).not_to be_optional
    end

    it "extracts validations" do
      names = attr.validations.map { |v| v[:name] }
      expect(names).to include(:presence)
    end

    it "is frozen" do
      expect(attr).to be_frozen
    end
  end

  describe "reader_name with :as" do
    it "uses the :as option" do
      attr = described_class.new(:user_id, { as: :uid })
      expect(attr.reader_name).to eq(:uid)
    end
  end

  describe "nested children" do
    it "reports nested?" do
      child = described_class.new(:street, { type: :string, required: true })
      parent = described_class.new(:address, { type: :hash }, [child])
      expect(parent).to be_nested
      expect(parent.children.size).to eq(1)
    end
  end

  describe "implicit presence for required" do
    it "adds presence validation when not explicit" do
      attr = described_class.new(:name, { required: true })
      names = attr.validations.map { |v| v[:name] }
      expect(names).to include(:presence)
    end

    it "does not double-add when explicit" do
      attr = described_class.new(:name, { required: true, presence: true })
      count = attr.validations.count { |v| v[:name] == :presence }
      expect(count).to eq(1)
    end
  end
end
