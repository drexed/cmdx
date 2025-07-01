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

    context "when running in test environment" do
      context "when RAILS_ENV is set to test" do
        around do |example|
          original_env = ENV.fetch("RAILS_ENV", nil)
          ENV["RAILS_ENV"] = "test"
          example.run
          ENV["RAILS_ENV"] = original_env
        end

        it "returns early without freezing any objects" do
          described_class.call(task)

          expect(task).not_to have_received(:freeze)
          expect(result).not_to have_received(:freeze)
          expect(context).not_to have_received(:freeze)
          expect(chain).not_to have_received(:freeze)
          expect(CMDx::Chain).not_to have_received(:clear)
        end
      end

      context "when RACK_ENV is set to test" do
        around do |example|
          original_env = ENV.fetch("RACK_ENV", nil)
          ENV["RACK_ENV"] = "test"
          example.run
          ENV["RACK_ENV"] = original_env
        end

        it "returns early without freezing any objects" do
          described_class.call(task)

          expect(task).not_to have_received(:freeze)
          expect(result).not_to have_received(:freeze)
          expect(context).not_to have_received(:freeze)
          expect(chain).not_to have_received(:freeze)
          expect(CMDx::Chain).not_to have_received(:clear)
        end
      end

      context "when both RAILS_ENV and RACK_ENV are set to test" do
        around do |example|
          original_rails_env = ENV.fetch("RAILS_ENV", nil)
          original_rack_env = ENV.fetch("RACK_ENV", nil)
          ENV["RAILS_ENV"] = "test"
          ENV["RACK_ENV"] = "test"
          example.run
          ENV["RAILS_ENV"] = original_rails_env
          ENV["RACK_ENV"] = original_rack_env
        end

        it "returns early without freezing any objects" do
          described_class.call(task)

          expect(task).not_to have_received(:freeze)
          expect(result).not_to have_received(:freeze)
          expect(context).not_to have_received(:freeze)
          expect(chain).not_to have_received(:freeze)
          expect(CMDx::Chain).not_to have_received(:clear)
        end
      end
    end

    context "when running in non-test environment" do
      around do |example|
        original_rails_env = ENV.fetch("RAILS_ENV", nil)
        original_rack_env = ENV.fetch("RACK_ENV", nil)
        ENV["RAILS_ENV"] = "production"
        ENV["RACK_ENV"] = "production"
        example.run
        ENV["RAILS_ENV"] = original_rails_env
        ENV["RACK_ENV"] = original_rack_env
      end

      context "when task result index is zero" do
        let(:result_index) { 0 }

        it "freezes task and result" do
          described_class.call(task)

          expect(task).to have_received(:freeze)
          expect(result).to have_received(:freeze)
        end

        it "freezes context and chain" do
          described_class.call(task)

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

        it "freezes task and result" do
          described_class.call(task)

          expect(task).to have_received(:freeze)
          expect(result).to have_received(:freeze)
        end

        it "does not freeze context and chain" do
          described_class.call(task)

          expect(context).not_to have_received(:freeze)
          expect(chain).not_to have_received(:freeze)
        end

        it "does not call Chain.clear" do
          described_class.call(task)

          expect(CMDx::Chain).not_to have_received(:clear)
        end
      end

      context "when task result index is a large number" do
        let(:result_index) { 99 }

        it "freezes task and result" do
          described_class.call(task)

          expect(task).to have_received(:freeze)
          expect(result).to have_received(:freeze)
        end

        it "does not freeze context and chain" do
          described_class.call(task)

          expect(context).not_to have_received(:freeze)
          expect(chain).not_to have_received(:freeze)
        end

        it "does not call Chain.clear" do
          described_class.call(task)

          expect(CMDx::Chain).not_to have_received(:clear)
        end
      end
    end

    context "when environment variables are not set" do
      around do |example|
        original_rails_env = ENV.fetch("RAILS_ENV", nil)
        original_rack_env = ENV.fetch("RACK_ENV", nil)
        ENV.delete("RAILS_ENV")
        ENV.delete("RACK_ENV")
        example.run
        ENV["RAILS_ENV"] = original_rails_env
        ENV["RACK_ENV"] = original_rack_env
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
      end

      context "when task result index is greater than zero" do
        let(:result_index) { 2 }

        it "freezes only task and result" do
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

    context "when environment variables are set to non-test values" do
      around do |example|
        original_rails_env = ENV.fetch("RAILS_ENV", nil)
        original_rack_env = ENV.fetch("RACK_ENV", nil)
        ENV["RAILS_ENV"] = "development"
        ENV["RACK_ENV"] = "development"
        example.run
        ENV["RAILS_ENV"] = original_rails_env
        ENV["RACK_ENV"] = original_rack_env
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
      end
    end

    context "when RAILS_ENV is test but RACK_ENV is not" do
      around do |example|
        original_rails_env = ENV.fetch("RAILS_ENV", nil)
        original_rack_env = ENV.fetch("RACK_ENV", nil)
        ENV["RAILS_ENV"] = "test"
        ENV["RACK_ENV"] = "production"
        example.run
        ENV["RAILS_ENV"] = original_rails_env
        ENV["RACK_ENV"] = original_rack_env
      end

      it "returns early without freezing any objects" do
        described_class.call(task)

        expect(task).not_to have_received(:freeze)
        expect(result).not_to have_received(:freeze)
        expect(context).not_to have_received(:freeze)
        expect(chain).not_to have_received(:freeze)
        expect(CMDx::Chain).not_to have_received(:clear)
      end
    end

    context "when RACK_ENV is test but RAILS_ENV is not" do
      around do |example|
        original_rails_env = ENV.fetch("RAILS_ENV", nil)
        original_rack_env = ENV.fetch("RACK_ENV", nil)
        ENV["RAILS_ENV"] = "production"
        ENV["RACK_ENV"] = "test"
        example.run
        ENV["RAILS_ENV"] = original_rails_env
        ENV["RACK_ENV"] = original_rack_env
      end

      it "does not return early because RAILS_ENV takes precedence" do
        described_class.call(task)

        expect(task).to have_received(:freeze)
        expect(result).to have_received(:freeze)
        expect(context).to have_received(:freeze)
        expect(chain).to have_received(:freeze)
        expect(CMDx::Chain).to have_received(:clear)
      end
    end

    context "when RACK_ENV is test and RAILS_ENV is nil" do
      around do |example|
        original_rails_env = ENV.fetch("RAILS_ENV", nil)
        original_rack_env = ENV.fetch("RACK_ENV", nil)
        ENV.delete("RAILS_ENV")
        ENV["RACK_ENV"] = "test"
        example.run
        ENV["RAILS_ENV"] = original_rails_env
        ENV["RACK_ENV"] = original_rack_env
      end

      it "returns early without freezing any objects" do
        described_class.call(task)

        expect(task).not_to have_received(:freeze)
        expect(result).not_to have_received(:freeze)
        expect(context).not_to have_received(:freeze)
        expect(chain).not_to have_received(:freeze)
        expect(CMDx::Chain).not_to have_received(:clear)
      end
    end

    context "when task result index is negative" do
      around do |example|
        original_rails_env = ENV.fetch("RAILS_ENV", nil)
        original_rack_env = ENV.fetch("RACK_ENV", nil)
        ENV["RAILS_ENV"] = "production"
        ENV["RACK_ENV"] = "production"
        example.run
        ENV["RAILS_ENV"] = original_rails_env
        ENV["RACK_ENV"] = original_rack_env
      end

      let(:result_index) { -1 }

      it "freezes task and result" do
        described_class.call(task)

        expect(task).to have_received(:freeze)
        expect(result).to have_received(:freeze)
      end

      it "does not freeze context and chain" do
        described_class.call(task)

        expect(context).not_to have_received(:freeze)
        expect(chain).not_to have_received(:freeze)
      end

      it "does not call Chain.clear" do
        described_class.call(task)

        expect(CMDx::Chain).not_to have_received(:clear)
      end
    end

    context "when task result index is exactly zero" do
      around do |example|
        original_rails_env = ENV.fetch("RAILS_ENV", nil)
        original_rack_env = ENV.fetch("RACK_ENV", nil)
        ENV["RAILS_ENV"] = "production"
        ENV["RACK_ENV"] = "production"
        example.run
        ENV["RAILS_ENV"] = original_rails_env
        ENV["RACK_ENV"] = original_rack_env
      end

      let(:result_index) { 0 }

      it "treats zero as the first task" do
        described_class.call(task)

        expect(context).to have_received(:freeze)
        expect(chain).to have_received(:freeze)
        expect(CMDx::Chain).to have_received(:clear)
      end
    end

    context "when task has freezing errors" do
      around do |example|
        original_rails_env = ENV.fetch("RAILS_ENV", nil)
        original_rack_env = ENV.fetch("RACK_ENV", nil)
        ENV["RAILS_ENV"] = "production"
        ENV["RACK_ENV"] = "production"
        example.run
        ENV["RAILS_ENV"] = original_rails_env
        ENV["RACK_ENV"] = original_rack_env
      end

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
