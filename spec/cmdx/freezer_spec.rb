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
        expect(task).not_to receive(:freeze)
        expect(result).not_to receive(:freeze)
        expect(context).not_to receive(:freeze)
        expect(chain).not_to receive(:freeze)

        allow(CMDx::Chain).to receive(:clear)

        described_class.immute(task)
      end
    end

    context "when SKIP_CMDX_FREEZING environment variable is falsy" do
      before do
        allow(ENV).to receive(:fetch).with("SKIP_CMDX_FREEZING", false).and_return("false")
        allow(CMDx::Coercions::Boolean).to receive(:call).with("false").and_return(false)
      end

      it "freezes the task and result" do
        allow(result).to receive(:index).and_return(1)
        expect(task).to receive(:freeze)
        expect(result).to receive(:freeze)

        described_class.immute(task)
      end

      context "when result index is zero" do
        before do
          allow(result).to receive(:index).and_return(0)
        end

        it "freezes task, result, context, and chain" do
          expect(task).to receive(:freeze)
          expect(result).to receive(:freeze)
          expect(context).to receive(:freeze)
          expect(chain).to receive(:freeze)

          described_class.immute(task)
        end

        it "clears the chain" do
          expect(CMDx::Chain).to receive(:clear).at_least(:once)

          described_class.immute(task)
        end
      end

      context "when result index is not zero" do
        before do
          allow(result).to receive(:index).and_return(2)
        end

        it "freezes only task and result" do
          expect(task).to receive(:freeze)
          expect(result).to receive(:freeze)
          expect(context).not_to receive(:freeze)
          expect(chain).not_to receive(:freeze)

          described_class.immute(task)
        end

        it "does not clear the chain" do
          # For non-zero index, Chain.clear should not be called by the method
          # We allow it to handle global setup calls but track our specific expectations
          call_count = 0
          allow(CMDx::Chain).to receive(:clear) { call_count += 1 }

          described_class.immute(task)

          # Since this test case has non-zero index, our method shouldn't call clear
          # Any calls should be from test setup only
          expect(call_count).to eq(0)
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
        expect(task).to receive(:freeze)
        expect(result).to receive(:freeze)
        expect(context).to receive(:freeze)
        expect(chain).to receive(:freeze)
        expect(CMDx::Chain).to receive(:clear).at_least(:once)

        described_class.immute(task)
      end
    end

    context "with edge cases" do
      before do
        allow(ENV).to receive(:fetch).with("SKIP_CMDX_FREEZING", false).and_return(false)
        allow(CMDx::Coercions::Boolean).to receive(:call).with(false).and_return(false)
      end

      it "handles negative index values" do
        allow(result).to receive(:index).and_return(-1)

        expect(task).to receive(:freeze)
        expect(result).to receive(:freeze)
        expect(context).not_to receive(:freeze)
        expect(chain).not_to receive(:freeze)

        # Track clear calls to ensure our method doesn't call it
        call_count = 0
        allow(CMDx::Chain).to receive(:clear) { call_count += 1 }

        described_class.immute(task)

        expect(call_count).to eq(0)
      end

      it "handles float index values by treating as non-zero" do
        allow(result).to receive(:index).and_return(1.5)

        expect(task).to receive(:freeze)
        expect(result).to receive(:freeze)
        expect(context).not_to receive(:freeze)
        expect(chain).not_to receive(:freeze)

        # Track clear calls to ensure our method doesn't call it
        call_count = 0
        allow(CMDx::Chain).to receive(:clear) { call_count += 1 }

        described_class.immute(task)

        expect(call_count).to eq(0)
      end
    end
  end
end
