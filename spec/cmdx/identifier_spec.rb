# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Identifier do
  subject(:identifier) { described_class }

  describe ".generate" do
    context "when SecureRandom responds to uuid_v7" do
      let(:uuid_v7) { "018f1234-5678-7000-8000-123456789abc" }

      before do
        allow(SecureRandom).to receive(:respond_to?).with(:uuid_v7).and_return(true)
        allow(SecureRandom).to receive(:uuid_v7).and_return(uuid_v7)
      end

      it "returns a UUID v7" do
        expect(identifier.generate).to eq(uuid_v7)
        expect(SecureRandom).to have_received(:uuid_v7)
      end

      it "does not call the fallback uuid method" do
        allow(SecureRandom).to receive(:uuid)

        identifier.generate

        expect(SecureRandom).not_to have_received(:uuid)
      end
    end

    context "when SecureRandom does not respond to uuid_v7" do
      let(:uuid_v4) { "f47ac10b-58cc-4372-a567-0e02b2c3d479" }

      before do
        allow(SecureRandom).to receive(:respond_to?).with(:uuid_v7).and_return(false)
        allow(SecureRandom).to receive(:uuid).and_return(uuid_v4)
      end

      it "returns a UUID v4 as fallback" do
        expect(identifier.generate).to eq(uuid_v4)
        expect(SecureRandom).to have_received(:uuid)
      end

      it "does not call uuid_v7" do
        allow(SecureRandom).to receive(:uuid_v7)

        identifier.generate

        expect(SecureRandom).not_to have_received(:uuid_v7)
      end
    end

    context "when called multiple times" do
      before do
        allow(SecureRandom).to receive(:respond_to?).with(:uuid_v7).and_return(true)
        allow(SecureRandom).to receive(:uuid_v7).and_return(
          "018f1234-5678-7000-8000-123456789abc",
          "018f1234-5678-7000-8000-123456789def"
        )
      end

      it "generates different UUIDs" do
        first_id = described_class.generate
        second_id = described_class.generate

        expect(first_id).not_to eq(second_id)
        expect(SecureRandom).to have_received(:uuid_v7).twice
      end
    end
  end
end
