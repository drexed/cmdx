# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ResultSerializer do
  describe ".call" do
    let(:task_class) do
      Class.new(CMDx::Task) do
        def call
          context.processed = true
        end
      end
    end

    let(:task) { task_class.new(order_id: 123) }

    context "when serializing a successful result" do
      let(:result) do
        task.perform
        task.result
      end

      it "returns a hash with basic result information" do
        serialized = described_class.call(result)

        expect(serialized).to include(
          state: "complete",
          status: "success",
          outcome: "success",
          metadata: {}
        )
        expect(serialized[:runtime]).to be_a(Numeric)
      end

      it "includes task serialization data" do
        serialized = described_class.call(result)

        expect(serialized).to include(
          class: nil,
          type: "Task",
          index: 0
        )
        expect(serialized[:id]).to be_a(String)
      end

      it "delegates to TaskSerializer for task information" do
        expect(CMDx::TaskSerializer).to receive(:call).with(task).and_call_original

        described_class.call(result)
      end
    end

    context "when serializing a failed result" do
      let(:failed_task) do
        Class.new(CMDx::Task) do
          def call
            fail!(reason: "Validation failed", code: 422, errors: ["Invalid email"])
          end
        end
      end

      let(:result) do
        instance = failed_task.new
        instance.perform
        instance.result
      end

      it "returns a hash with failed state and metadata" do
        serialized = described_class.call(result)

        expect(serialized).to include(
          state: "interrupted",
          status: "failed",
          outcome: "failed",
          metadata: {
            reason: "Validation failed",
            code: 422,
            errors: ["Invalid email"]
          }
        )
      end

      it "includes runtime information" do
        serialized = described_class.call(result)

        expect(serialized[:runtime]).to be_a(Numeric)
        expect(serialized[:runtime]).to be >= 0
      end
    end

    context "when serializing a skipped result" do
      let(:skipped_task) do
        Class.new(CMDx::Task) do
          def call
            skip!(reason: "Order already processed")
          end
        end
      end

      let(:result) do
        instance = skipped_task.new
        instance.perform
        instance.result
      end

      it "returns a hash with skipped state and metadata" do
        serialized = described_class.call(result)

        expect(serialized).to include(
          state: "interrupted",
          status: "skipped",
          outcome: "skipped",
          metadata: { reason: "Order already processed" }
        )
      end
    end

    context "when result has failure chain information" do
      let(:failing_task) do
        Class.new(CMDx::Task) do
          def call
            fail!(reason: "Processing failed")
          end
        end
      end

      let(:caused_failure_result) do
        instance = failing_task.new
        instance.perform
        instance.result
      end

      let(:threw_failure_result) do
        instance = failing_task.new
        instance.perform
        instance.result
      end

      let(:main_result) do
        instance = failing_task.new
        instance.perform
        result = instance.result

        # Mock failure chain methods
        allow(result).to receive_messages(failed?: true, caused_failure?: false, threw_failure?: false, caused_failure: caused_failure_result, threw_failure: threw_failure_result)

        result
      end

      it "includes caused_failure information without recursion" do
        allow(caused_failure_result).to receive(:to_h).and_return(
          class: "ValidationTask",
          state: "interrupted",
          status: "failed",
          caused_failure: { nested: "data" },
          threw_failure: { nested: "data" }
        )

        serialized = described_class.call(main_result)

        expect(serialized[:caused_failure]).to eq(
          class: "ValidationTask",
          state: "interrupted",
          status: "failed"
        )
      end

      it "includes threw_failure information without recursion" do
        allow(threw_failure_result).to receive(:to_h).and_return(
          class: "ProcessingTask",
          state: "interrupted",
          status: "failed",
          caused_failure: { nested: "data" },
          threw_failure: { nested: "data" }
        )

        serialized = described_class.call(main_result)

        expect(serialized[:threw_failure]).to eq(
          class: "ProcessingTask",
          state: "interrupted",
          status: "failed"
        )
      end

      it "strips nested failure information to prevent recursion" do
        failure_data = {
          class: "NestedTask",
          state: "interrupted",
          status: "failed",
          caused_failure: { deeply: { nested: "failure" } },
          threw_failure: { deeply: { nested: "failure" } }
        }

        allow(caused_failure_result).to receive(:to_h).and_return(failure_data)

        serialized = described_class.call(main_result)

        expect(serialized[:caused_failure]).not_to have_key(:caused_failure)
        expect(serialized[:caused_failure]).not_to have_key(:threw_failure)
      end
    end

    context "when result does not have failure chain" do
      let(:simple_failed_task) do
        Class.new(CMDx::Task) do
          def call
            fail!(reason: "Simple failure")
          end
        end
      end

      let(:result) do
        instance = simple_failed_task.new
        instance.perform
        result = instance.result

        # Mock no failure chain
        allow(result).to receive_messages(caused_failure?: true, threw_failure?: true)

        result
      end

      it "does not include caused_failure when not present" do
        serialized = described_class.call(result)

        expect(serialized).not_to have_key(:caused_failure)
      end

      it "does not include threw_failure when not present" do
        serialized = described_class.call(result)

        expect(serialized).not_to have_key(:threw_failure)
      end
    end

    context "when serializing different result outcomes" do
      it "correctly identifies success outcome" do
        task.perform
        serialized = described_class.call(task.result)

        expect(serialized[:outcome]).to eq("success")
      end

      it "correctly identifies failed outcome" do
        failed_task = Class.new(CMDx::Task) do
          def call
            fail!(reason: "Test failure")
          end
        end

        instance = failed_task.new
        instance.perform
        serialized = described_class.call(instance.result)

        expect(serialized[:outcome]).to eq("failed")
      end

      it "correctly identifies skipped outcome" do
        skipped_task = Class.new(CMDx::Task) do
          def call
            skip!(reason: "Test skip")
          end
        end

        instance = skipped_task.new
        instance.perform
        serialized = described_class.call(instance.result)

        expect(serialized[:outcome]).to eq("skipped")
      end
    end
  end
end
