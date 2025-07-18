# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Correlator do
  describe ".generate" do
    context "when SecureRandom.uuid_v7 is available" do
      before do
        allow(SecureRandom).to receive(:respond_to?).with(:uuid_v7).and_return(true)
        allow(SecureRandom).to receive(:uuid_v7).and_return("01234567-89ab-7def-0123-456789abcdef")
      end

      it "uses uuid_v7" do
        result = described_class.generate

        expect(result).to eq("01234567-89ab-7def-0123-456789abcdef")
        expect(SecureRandom).to have_received(:uuid_v7)
      end
    end

    context "when SecureRandom.uuid_v7 is not available" do
      before do
        allow(SecureRandom).to receive(:respond_to?).with(:uuid_v7).and_return(false)
        allow(SecureRandom).to receive(:uuid).and_return("f47ac10b-58cc-4372-a567-0e02b2c3d479")
      end

      it "falls back to uuid" do
        result = described_class.generate

        expect(result).to eq("f47ac10b-58cc-4372-a567-0e02b2c3d479")
        expect(SecureRandom).to have_received(:uuid)
      end
    end

    it "returns a string" do
      result = described_class.generate

      expect(result).to be_a(String)
    end
  end

  describe ".id" do
    after { described_class.clear }

    it "returns nil when no correlation ID is set" do
      described_class.clear

      expect(described_class.id).to be_nil
    end

    it "returns the current correlation ID when set" do
      described_class.id = "test-correlation-123"

      expect(described_class.id).to eq("test-correlation-123")
    end
  end

  describe ".id=" do
    after { described_class.clear }

    it "sets the correlation ID" do
      described_class.id = "new-correlation-456"

      expect(Thread.current[:cmdx_correlation_id]).to eq("new-correlation-456")
    end

    it "returns the value that was set" do
      result = described_class.id = "return-test-789"

      expect(result).to eq("return-test-789")
    end

    it "accepts symbols" do
      described_class.id = :symbol_correlation

      expect(described_class.id).to eq(:symbol_correlation)
    end
  end

  describe ".clear" do
    it "clears the correlation ID" do
      described_class.id = "to-be-cleared"

      described_class.clear

      expect(described_class.id).to be_nil
    end

    it "returns nil" do
      result = described_class.clear

      expect(result).to be_nil
    end

    it "does not raise error when correlation ID is already nil" do
      described_class.clear

      expect { described_class.clear }.not_to raise_error
    end
  end

  describe ".use" do
    let(:original_id) { "original-123" }
    let(:temporary_id) { "temp-456" }

    before { described_class.id = original_id }
    after { described_class.clear }

    it "temporarily sets correlation ID during block execution" do
      block_correlation_id = nil

      described_class.use(temporary_id) do
        block_correlation_id = described_class.id
      end

      expect(block_correlation_id).to eq(temporary_id)
    end

    it "restores original correlation ID after block execution" do
      described_class.use(temporary_id) { nil }

      expect(described_class.id).to eq(original_id)
    end

    it "returns the result of the block" do
      result = described_class.use(temporary_id) do
        "block-result"
      end

      expect(result).to eq("block-result")
    end

    it "accepts symbols" do
      block_correlation_id = nil

      described_class.use(:symbol_temp) do
        block_correlation_id = described_class.id
      end

      expect(block_correlation_id).to eq(:symbol_temp)
    end

    context "when original correlation ID is nil" do
      before { described_class.clear }

      it "restores nil after block execution" do
        described_class.use(temporary_id) { nil }

        expect(described_class.id).to be_nil
      end
    end

    context "when block raises an exception" do
      it "restores original correlation ID" do
        expect do
          described_class.use(temporary_id) do
            raise StandardError, "test error"
          end
        end.to raise_error(StandardError, "test error")

        expect(described_class.id).to eq(original_id)
      end

      it "propagates the exception" do
        expect do
          described_class.use(temporary_id) do
            raise ArgumentError, "custom error"
          end
        end.to raise_error(ArgumentError, "custom error")
      end
    end

    context "with invalid input types" do
      it "raises TypeError for numeric values" do
        expect do
          described_class.use(123) { nil }
        end.to raise_error(TypeError, "must be a String or Symbol")
      end

      it "raises TypeError for arrays" do
        expect do
          described_class.use(["array"]) { nil }
        end.to raise_error(TypeError, "must be a String or Symbol")
      end

      it "raises TypeError for hashes" do
        expect do
          described_class.use({ key: "value" }) { nil }
        end.to raise_error(TypeError, "must be a String or Symbol")
      end

      it "raises TypeError for nil" do
        expect do
          described_class.use(nil) { nil }
        end.to raise_error(TypeError, "must be a String or Symbol")
      end
    end
  end

  describe "thread safety" do
    after { described_class.clear }

    it "maintains separate correlation IDs across threads" do
      main_id = "main-thread"
      thread_id = "worker-thread"
      thread_correlation_id = nil

      described_class.id = main_id

      thread = Thread.new do
        described_class.id = thread_id
        thread_correlation_id = described_class.id
      end

      thread.join

      expect(described_class.id).to eq(main_id)
      expect(thread_correlation_id).to eq(thread_id)
    end
  end
end
