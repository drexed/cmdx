# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LazyStruct do
  subject(:struct) { described_class.new(name: "John Doe") }

  let(:email) { "john.doe@example.com" }
  let(:phone_number) { "555-8374" }

  describe "#initialize" do
    context "when invalid argument provided" do
      it "raises ArgumentError for non-hash-like objects" do
        expect { described_class.new(123) }.to raise_error(ArgumentError, "must be respond to `to_h`")
      end
    end
  end

  describe "#[]" do
    it "stores and retrieves key-value pairs" do
      struct["email"] = email

      expect(struct["email"]).to eq(email)
    end
  end

  describe "#fetch!" do
    context "when key exists" do
      it "returns the value" do
        expect(struct.fetch!("name")).to eq("John Doe")
      end
    end

    context "when key does not exist" do
      let(:missing_key) { :fake }

      it "raises KeyError without default" do
        expect { struct.fetch!(missing_key) }.to raise_error(KeyError)
      end

      it "returns default value when provided" do
        expect(struct.fetch!(missing_key, 123)).to eq(123)
      end

      it "returns block result when block provided" do
        expect(struct.fetch!(missing_key) { 456 }).to eq(456)
      end
    end
  end

  describe "#store!" do
    context "when using direct method call" do
      it "adds key-value pair" do
        struct.store!("email", email)

        expect(struct.email).to eq(email)
      end
    end

    context "when using method_missing" do
      it "adds key-value pair through assignment" do
        struct.email = email

        expect(struct.email).to eq(email)
      end
    end
  end

  describe "#merge!" do
    it "merges multiple key-value pairs at once" do
      struct.merge!(phone_number: phone_number, "email" => email)

      expect(struct.to_h).to eq(
        name: "John Doe",
        phone_number: phone_number,
        email: email
      )
    end
  end

  describe "#delete!" do
    before do
      struct["email"] = email
    end

    it "removes key-value pairs by key" do
      struct.delete!(:name)
      struct.delete!("email")

      expect(struct.to_h).to eq({})
    end
  end

  describe "#eql?" do
    context "when comparing with different class" do
      it "returns false" do
        expect(struct.eql?(123)).to be(false)
      end
    end

    context "when comparing with same class" do
      context "with identical values" do
        let(:other_struct) { described_class.new(name: "John Doe") }

        it "returns true" do
          expect(struct.eql?(other_struct)).to be(true)
        end
      end

      context "with different values" do
        let(:other_struct) { described_class.new(name: "Jane Doe") }

        it "returns false" do
          expect(struct.eql?(other_struct)).to be(false)
        end
      end
    end
  end

  describe "#dig" do
    context "when nested key path exists" do
      let(:struct) { described_class.new(user: { "name" => "Bill Foe" }) }

      it "returns nested value" do
        expect(struct.dig(:user, "name")).to eq("Bill Foe")
      end
    end

    context "when key path does not exist" do
      it "returns nil" do
        expect(struct.dig(:user, "name")).to be_nil
      end
    end

    context "when invalid key types provided" do
      it "raises TypeError" do
        expect { struct.dig(123, 456) }.to raise_error(TypeError, "123 is not a symbol nor a string")
      end
    end
  end

  describe "#inspect" do
    it "returns formatted inspection string" do
      expect(struct.inspect).to eq('#<CMDx::LazyStruct:name="John Doe">')
    end
  end
end
