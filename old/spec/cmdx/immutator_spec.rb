# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Immutator do
  describe ".call" do
    let(:task) { double("Task", freeze: true) }
    let(:result) { double("Result", freeze: true, index: index) }
    let(:context) { double("Context", freeze: true) }
    let(:chain) { double("Chain", freeze: true) }

    before do
      allow(task).to receive_messages(result: result, context: context, chain: chain)
      allow(CMDx::Chain).to receive(:clear)
      ENV.delete("SKIP_CMDX_FREEZING") # Ensure freezing is enabled for unit tests
    end

    after do
      ENV["SKIP_CMDX_FREEZING"] = "1" # Reset to default test environment
    end

    context "when SKIP_CMDX_FREEZING is set to truthy value" do
      let(:index) { 0 }

      before do
        ENV["SKIP_CMDX_FREEZING"] = "true"
      end

      it "skips all freezing operations" do
        described_class.call(task)

        expect(task).not_to have_received(:freeze)
        expect(result).not_to have_received(:freeze)
        expect(context).not_to have_received(:freeze)
        expect(chain).not_to have_received(:freeze)
        expect(CMDx::Chain).not_to have_received(:clear)
      end

      it "returns nil immediately" do
        result = described_class.call(task)

        expect(result).to be_nil
      end
    end

    context "when SKIP_CMDX_FREEZING is set to string '1'" do
      let(:index) { 0 }

      before do
        ENV["SKIP_CMDX_FREEZING"] = "1"
      end

      it "skips freezing operations" do
        described_class.call(task)

        expect(task).not_to have_received(:freeze)
        expect(result).not_to have_received(:freeze)
      end
    end

    context "when SKIP_CMDX_FREEZING is set to falsy value" do
      before do
        ENV["SKIP_CMDX_FREEZING"] = "false"
      end

      after do
        ENV.delete("SKIP_CMDX_FREEZING")
      end

      let(:index) { 1 }

      it "proceeds with freezing operations" do
        described_class.call(task)

        expect(task).to have_received(:freeze)
        expect(result).to have_received(:freeze)
      end
    end

    context "when SKIP_CMDX_FREEZING is not set" do
      before do
        ENV.delete("SKIP_CMDX_FREEZING")
      end

      let(:index) { 0 }

      it "proceeds with freezing operations" do
        described_class.call(task)

        expect(task).to have_received(:freeze)
        expect(result).to have_received(:freeze)
      end
    end

    context "when task is not the first in chain (index > 0)" do
      let(:index) { 2 }

      it "freezes task and result only" do
        described_class.call(task)

        expect(task).to have_received(:freeze)
        expect(result).to have_received(:freeze)
        expect(context).not_to have_received(:freeze)
        expect(chain).not_to have_received(:freeze)
        expect(CMDx::Chain).not_to have_received(:clear)
      end

      it "returns nil" do
        result = described_class.call(task)

        expect(result).to be_nil
      end
    end

    context "when task is the first in chain (index = 0)" do
      let(:index) { 0 }

      it "freezes all objects" do
        described_class.call(task)

        expect(task).to have_received(:freeze)
        expect(result).to have_received(:freeze)
        expect(context).to have_received(:freeze)
        expect(chain).to have_received(:freeze)
      end

      it "clears the chain" do
        described_class.call(task)

        expect(CMDx::Chain).to have_received(:clear)
      end

      it "returns nil" do
        result = described_class.call(task)

        expect(result).to be_nil
      end
    end

    context "when freezing operations fail" do
      let(:index) { 0 }

      it "propagates task freeze errors" do
        allow(task).to receive(:freeze).and_raise(StandardError, "Freeze failed")

        expect { described_class.call(task) }.to raise_error(StandardError, "Freeze failed")
      end

      it "propagates result freeze errors" do
        allow(result).to receive(:freeze).and_raise(RuntimeError, "Result freeze failed")

        expect { described_class.call(task) }.to raise_error(RuntimeError, "Result freeze failed")
      end

      it "propagates context freeze errors" do
        allow(context).to receive(:freeze).and_raise(FrozenError, "Context freeze failed")

        expect { described_class.call(task) }.to raise_error(FrozenError, "Context freeze failed")
      end
    end
  end
end
