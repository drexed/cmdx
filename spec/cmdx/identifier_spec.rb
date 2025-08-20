# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Identifier, type: :unit do
  subject(:identifier) { described_class }

  describe ".generate" do
    context "when SecureRandom responds to uuid_v7" do
      let(:uuid_v7) { "018f1234-5678-7000-8000-123456789abc" }

      before do
        allow(SecureRandom).to receive(:respond_to?).with(:uuid_v7).and_return(true)
      end

      it "returns a UUID v7" do
        allow(SecureRandom).to receive(:uuid_v7).and_return(uuid_v7)

        expect(identifier.generate).to eq(uuid_v7)
      end

      it "does not call the fallback uuid method" do
        skip("Not supported on Ruby versions prior to 3.4") unless RubyVersion.min?(3.4)

        expect(SecureRandom).not_to receive(:uuid)

        identifier.generate
      end
    end

    context "when SecureRandom does not respond to uuid_v7" do
      let(:uuid_v4) { "f47ac10b-58cc-4372-a567-0e02b2c3d479" }

      before do
        allow(SecureRandom).to receive(:respond_to?).with(:uuid_v7).and_return(false)
      end

      it "returns a UUID v4 as fallback" do
        allow(SecureRandom).to receive(:uuid).and_return(uuid_v4)

        expect(identifier.generate).to eq(uuid_v4)
      end

      it "does not call uuid_v7" do
        expect(SecureRandom).not_to receive(:uuid_v7)

        identifier.generate
      end
    end

    context "when called multiple times" do
      before do
        allow(SecureRandom).to receive(:respond_to?).with(:uuid_v7).and_return(true)
      end

      it "generates different UUIDs" do
        allow(SecureRandom).to receive(:uuid_v7).and_return(
          "018f1234-5678-7000-8000-123456789abc",
          "018f1234-5678-7000-8000-123456789def"
        )

        first_id = described_class.generate
        second_id = described_class.generate

        expect(first_id).not_to eq(second_id)
      end
    end
  end
end
