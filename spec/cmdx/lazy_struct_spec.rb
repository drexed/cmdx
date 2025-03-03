# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LazyStruct do
  subject(:struct) { described_class.new(name: "John Doe") }

  describe "#initialize" do
    it "raises an ArgumentError" do
      expect { described_class.new(123) }.to raise_error(ArgumentError, "must be respond to `to_h`")
    end
  end

  describe ".[]" do
    it "removes a key value pair" do
      struct["email"] = "john.doe@example.com"

      expect(struct["email"]).to eq("john.doe@example.com")
    end
  end

  describe ".fetch!" do
    context "when key value pair exists" do
      it "returns value" do
        expect(struct.fetch!("name")).to eq("John Doe")
      end
    end

    context "when key value pair missing" do
      it "raises KeyError" do
        expect { struct.fetch!(:fake) }.to raise_error(KeyError)
      end

      it "returns default value" do
        expect(struct.fetch!(:fake, 123)).to eq(123)
      end

      it "returns block value" do
        expect(struct.fetch!(:fake) { 456 }).to eq(456)
      end
    end
  end

  describe ".store!" do
    context "when using method" do
      it "adds key value pair" do
        struct.store!("email", "john.doe@example.com")

        expect(struct.email).to eq("john.doe@example.com")
      end
    end

    context "when using method_missing" do
      it "adds key value pair" do
        struct.email = "john.doe@example.com"

        expect(struct.email).to eq("john.doe@example.com")
      end
    end
  end

  describe ".merge!" do
    it "adds all key value pairs" do
      struct.merge!(phone_number: "555-8374", "email" => "john.doe@example.com")

      expect(struct.to_h).to eq(
        name: "John Doe",
        phone_number: "555-8374",
        email: "john.doe@example.com"
      )
    end
  end

  describe ".delete!" do
    it "removes a key value pair" do
      struct["email"] = "john.doe@example.com"
      struct.delete!(:name)
      struct.delete!("email")

      expect(struct.to_h).to eq({})
    end
  end

  describe ".eql?" do
    context "when different classes" do
      it "returns false" do
        expect(struct.eql?(123)).to be(false)
      end
    end

    context "with same values" do
      it "returns true" do
        other_struct = described_class.new(name: "John Doe")

        expect(struct.eql?(other_struct)).to be(true)
      end
    end

    context "with different values" do
      it "returns true" do
        other_struct = described_class.new(name: "Jane Doe")

        expect(struct.eql?(other_struct)).to be(false)
      end
    end
  end

  describe ".dig" do
    context "when key value pair exists" do
      let(:struct) { described_class.new(user: { "name" => "Bill Foe" }) }

      it "returns value" do
        expect(struct.dig(:user, "name")).to eq("Bill Foe")
      end
    end

    context "when key value pair missing" do
      it "returns nil" do
        expect(struct.dig(:user, "name")).to be_nil
      end
    end

    context "when invalid arguments" do
      it "raises KeyError" do
        expect { struct.dig(123, 456) }.to raise_error(TypeError, "123 is not a symbol nor a string")
      end
    end
  end

  describe ".inspect" do
    it "returns formatted string" do
      expect(struct.inspect).to eq('#<CMDx::LazyStruct:name="John Doe">')
    end
  end
end
