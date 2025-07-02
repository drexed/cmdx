# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Immutator do
  describe ".call" do
    let(:chain) { double("Chain") }
    let(:context) { double("Context") }
    let(:result) { double("Result", index: result_index) }
    let(:task) { double("Task", result: result, context: context, chain: chain) }
    let(:result_index) { 0 }

    before do
      allow(task).to receive(:freeze)
      allow(result).to receive(:freeze)
      allow(context).to receive(:freeze)
      allow(chain).to receive(:freeze)
      allow(CMDx::Chain).to receive(:clear)
    end

    context "when SKIP_CMDX_FREEZING is set to truthy value" do
      around do |example|
        original_env = ENV.fetch("SKIP_CMDX_FREEZING", nil)
        ENV["SKIP_CMDX_FREEZING"] = "1"
        example.run
        if original_env
          ENV["SKIP_CMDX_FREEZING"] = original_env
        else
          ENV.delete("SKIP_CMDX_FREEZING")
        end
      end

      it "returns early without freezing any objects" do
        described_class.call(task)

        expect(task).not_to have_received(:freeze)
        expect(result).not_to have_received(:freeze)
        expect(context).not_to have_received(:freeze)
        expect(chain).not_to have_received(:freeze)
        expect(CMDx::Chain).not_to have_received(:clear)
      end

      it "works regardless of task result index" do
        [0, 1, 5, -1].each do |index|
          allow(result).to receive(:index).and_return(index)
          described_class.call(task)

          expect(task).not_to have_received(:freeze)
          expect(result).not_to have_received(:freeze)
          expect(context).not_to have_received(:freeze)
          expect(chain).not_to have_received(:freeze)
          expect(CMDx::Chain).not_to have_received(:clear)
        end
      end
    end

    context "when SKIP_CMDX_FREEZING is set to falsy value" do
      around do |example|
        original_env = ENV.fetch("SKIP_CMDX_FREEZING", nil)
        ENV["SKIP_CMDX_FREEZING"] = "false"
        example.run
        if original_env
          ENV["SKIP_CMDX_FREEZING"] = original_env
        else
          ENV.delete("SKIP_CMDX_FREEZING")
        end
      end

      context "when task result index is zero" do
        let(:result_index) { 0 }

        it "freezes all objects" do
          described_class.call(task)

          expect(task).to have_received(:freeze)
          expect(result).to have_received(:freeze)
          expect(context).to have_received(:freeze)
          expect(chain).to have_received(:freeze)
        end

        it "calls Chain.clear" do
          described_class.call(task)

          expect(CMDx::Chain).to have_received(:clear)
        end

        it "performs all operations in correct order" do
          described_class.call(task)

          expect(task).to have_received(:freeze).ordered
          expect(result).to have_received(:freeze).ordered
          expect(context).to have_received(:freeze).ordered
          expect(chain).to have_received(:freeze).ordered
          expect(CMDx::Chain).to have_received(:clear).ordered
        end
      end

      context "when task result index is greater than zero" do
        let(:result_index) { 1 }

        it "freezes task and result only" do
          described_class.call(task)

          expect(task).to have_received(:freeze)
          expect(result).to have_received(:freeze)
          expect(context).not_to have_received(:freeze)
          expect(chain).not_to have_received(:freeze)
        end

        it "does not call Chain.clear" do
          described_class.call(task)

          expect(CMDx::Chain).not_to have_received(:clear)
        end
      end
    end

    context "when SKIP_CMDX_FREEZING is not set" do
      around do |example|
        original_env = ENV.fetch("SKIP_CMDX_FREEZING", nil)
        ENV.delete("SKIP_CMDX_FREEZING")
        example.run
        ENV["SKIP_CMDX_FREEZING"] = original_env if original_env
      end

      context "when task result index is zero" do
        let(:result_index) { 0 }

        it "freezes all objects" do
          described_class.call(task)

          expect(task).to have_received(:freeze)
          expect(result).to have_received(:freeze)
          expect(context).to have_received(:freeze)
          expect(chain).to have_received(:freeze)
        end

        it "calls Chain.clear" do
          described_class.call(task)

          expect(CMDx::Chain).to have_received(:clear)
        end

        it "performs all operations in correct order" do
          described_class.call(task)

          expect(task).to have_received(:freeze).ordered
          expect(result).to have_received(:freeze).ordered
          expect(context).to have_received(:freeze).ordered
          expect(chain).to have_received(:freeze).ordered
          expect(CMDx::Chain).to have_received(:clear).ordered
        end
      end

      context "when task result index is greater than zero" do
        let(:result_index) { 1 }

        it "freezes task and result only" do
          described_class.call(task)

          expect(task).to have_received(:freeze)
          expect(result).to have_received(:freeze)
          expect(context).not_to have_received(:freeze)
          expect(chain).not_to have_received(:freeze)
        end

        it "does not call Chain.clear" do
          described_class.call(task)

          expect(CMDx::Chain).not_to have_received(:clear)
        end
      end

      context "when task result index is negative" do
        let(:result_index) { -1 }

        it "freezes task and result only" do
          described_class.call(task)

          expect(task).to have_received(:freeze)
          expect(result).to have_received(:freeze)
          expect(context).not_to have_received(:freeze)
          expect(chain).not_to have_received(:freeze)
        end

        it "does not call Chain.clear" do
          described_class.call(task)

          expect(CMDx::Chain).not_to have_received(:clear)
        end
      end

      context "when task result index is exactly zero" do
        let(:result_index) { 0 }

        it "treats zero as the first task" do
          described_class.call(task)

          expect(context).to have_received(:freeze)
          expect(chain).to have_received(:freeze)
          expect(CMDx::Chain).to have_received(:clear)
        end
      end

      context "when task has freezing errors" do
        let(:result_index) { 0 }

        it "propagates freezing errors" do
          allow(task).to receive(:freeze).and_raise(StandardError, "Freeze failed")

          expect { described_class.call(task) }.to raise_error(StandardError, "Freeze failed")
        end

        it "propagates result freezing errors" do
          allow(result).to receive(:freeze).and_raise(StandardError, "Result freeze failed")

          expect { described_class.call(task) }.to raise_error(StandardError, "Result freeze failed")
        end

        it "propagates context freezing errors" do
          allow(context).to receive(:freeze).and_raise(StandardError, "Context freeze failed")

          expect { described_class.call(task) }.to raise_error(StandardError, "Context freeze failed")
        end

        it "propagates chain freezing errors" do
          allow(chain).to receive(:freeze).and_raise(StandardError, "Chain freeze failed")

          expect { described_class.call(task) }.to raise_error(StandardError, "Chain freeze failed")
        end

        it "propagates Chain.clear errors" do
          allow(CMDx::Chain).to receive(:clear).and_raise(StandardError, "Clear failed")

          expect { described_class.call(task) }.to raise_error(StandardError, "Clear failed")

          # Reset the mock to allow RSpec cleanup to work properly
          allow(CMDx::Chain).to receive(:clear).and_call_original
        end
      end
    end
  end
end
