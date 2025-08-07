# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Freezer do
  describe "#immute" do
    let(:task) { instance_double(CMDx::Task) }
    let(:result) { instance_double(CMDx::Result) }
    let(:context) { instance_double(CMDx::Context) }
    let(:chain) { instance_double(CMDx::Chain) }

    before do
      allow(task).to receive_messages(result: result, context: context, chain: chain)
      allow(task).to receive(:freeze)
      allow(result).to receive(:freeze)
      allow(context).to receive(:freeze)
      allow(chain).to receive(:freeze)
      allow(CMDx::Chain).to receive(:clear)
    end

    context "when SKIP_CMDX_FREEZING environment variable is truthy" do
      before do
        allow(ENV).to receive(:fetch).with("SKIP_CMDX_FREEZING", false).and_return("true")
        allow(CMDx::Coercions::Boolean).to receive(:call).with("true").and_return(true)
      end

      it "returns early without freezing anything" do
        described_class.immute(task)

        expect(task).not_to have_received(:freeze)
        expect(result).not_to have_received(:freeze)
        expect(context).not_to have_received(:freeze)
        expect(chain).not_to have_received(:freeze)
        expect(CMDx::Chain).not_to have_received(:clear)
      end
    end

    context "when SKIP_CMDX_FREEZING environment variable is falsy" do
      before do
        allow(ENV).to receive(:fetch).with("SKIP_CMDX_FREEZING", false).and_return("false")
        allow(CMDx::Coercions::Boolean).to receive(:call).with("false").and_return(false)
      end

      it "freezes the task and result" do
        allow(result).to receive(:index).and_return(1)

        described_class.immute(task)

        expect(task).to have_received(:freeze)
        expect(result).to have_received(:freeze)
      end

      context "when result index is zero" do
        before do
          allow(result).to receive(:index).and_return(0)
        end

        it "freezes task, result, context, and chain" do
          described_class.immute(task)

          expect(task).to have_received(:freeze)
          expect(result).to have_received(:freeze)
          expect(context).to have_received(:freeze)
          expect(chain).to have_received(:freeze)
        end

        it "clears the chain" do
          described_class.immute(task)

          expect(CMDx::Chain).to have_received(:clear)
        end
      end

      context "when result index is not zero" do
        before do
          allow(result).to receive(:index).and_return(2)
        end

        it "freezes only task and result" do
          described_class.immute(task)

          expect(task).to have_received(:freeze)
          expect(result).to have_received(:freeze)
          expect(context).not_to have_received(:freeze)
          expect(chain).not_to have_received(:freeze)
        end

        it "does not clear the chain" do
          described_class.immute(task)

          expect(CMDx::Chain).not_to have_received(:clear)
        end
      end
    end

    context "when SKIP_CMDX_FREEZING is not set" do
      before do
        allow(ENV).to receive(:fetch).with("SKIP_CMDX_FREEZING", false).and_return(false)
        allow(CMDx::Coercions::Boolean).to receive(:call).with(false).and_return(false)
      end

      it "proceeds with normal freezing behavior" do
        allow(result).to receive(:index).and_return(0)

        described_class.immute(task)

        expect(task).to have_received(:freeze)
        expect(result).to have_received(:freeze)
        expect(context).to have_received(:freeze)
        expect(chain).to have_received(:freeze)
        expect(CMDx::Chain).to have_received(:clear)
      end
    end

    context "with edge cases" do
      before do
        allow(ENV).to receive(:fetch).with("SKIP_CMDX_FREEZING", false).and_return(false)
        allow(CMDx::Coercions::Boolean).to receive(:call).with(false).and_return(false)
      end

      it "handles negative index values" do
        allow(result).to receive(:index).and_return(-1)

        described_class.immute(task)

        expect(task).to have_received(:freeze)
        expect(result).to have_received(:freeze)
        expect(context).not_to have_received(:freeze)
        expect(chain).not_to have_received(:freeze)
        expect(CMDx::Chain).not_to have_received(:clear)
      end

      it "handles float index values by treating as non-zero" do
        allow(result).to receive(:index).and_return(1.5)

        described_class.immute(task)

        expect(task).to have_received(:freeze)
        expect(result).to have_received(:freeze)
        expect(context).not_to have_received(:freeze)
        expect(chain).not_to have_received(:freeze)
        expect(CMDx::Chain).not_to have_received(:clear)
      end
    end
  end
end
