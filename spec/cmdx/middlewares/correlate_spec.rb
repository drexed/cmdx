# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middlewares::Correlate, type: :unit do
  subject(:correlate) { described_class }

  let(:task) { double("CMDx::Task", id: "task-123", result: result) } # rubocop:disable RSpec/VerifiedDoubles
  let(:result) { instance_double(CMDx::Result, metadata: metadata) }
  let(:metadata) { {} }

  before do
    described_class.clear
  end

  describe ".id" do
    context "when no correlation ID is set" do
      it "returns nil" do
        expect(correlate.id).to be_nil
      end
    end

    context "when correlation ID is set" do
      before { correlate.id = "test-correlation-id" }

      it "returns the correlation ID" do
        expect(correlate.id).to eq("test-correlation-id")
      end
    end
  end

  describe ".id=" do
    it "sets the correlation ID in thread local storage" do
      correlate.id = "new-correlation-id"

      expect(correlate.id).to eq("new-correlation-id")
    end

    it "overwrites existing correlation ID" do
      correlate.id = "first-id"
      correlate.id = "second-id"

      expect(correlate.id).to eq("second-id")
    end

    it "accepts nil values" do
      correlate.id = "some-id"
      correlate.id = nil

      expect(correlate.id).to be_nil
    end
  end

  describe ".clear" do
    it "sets correlation ID to nil" do
      correlate.id = "test-id"

      correlate.clear

      expect(correlate.id).to be_nil
    end

    context "when no ID was set" do
      it "remains nil" do
        correlate.clear

        expect(correlate.id).to be_nil
      end
    end
  end

  describe ".use" do
    let(:new_id) { "temporary-id" }
    let(:block_result) { "block executed" }

    context "when no existing ID is set" do
      it "sets the new ID during block execution" do
        called_with_id = nil

        correlate.use(new_id) do
          called_with_id = correlate.id
        end

        expect(called_with_id).to eq(new_id)
      end

      it "clears the ID after block execution" do
        correlate.use(new_id) { nil }

        expect(correlate.id).to be_nil
      end

      it "returns the block result" do
        result = correlate.use(new_id) { block_result }

        expect(result).to eq(block_result)
      end
    end

    context "when existing ID is set" do
      let(:original_id) { "original-id" }

      before { correlate.id = original_id }

      it "temporarily replaces the ID during block execution" do
        called_with_id = nil

        correlate.use(new_id) do
          called_with_id = correlate.id
        end

        expect(called_with_id).to eq(new_id)
      end

      it "restores the original ID after block execution" do
        correlate.use(new_id) { nil }

        expect(correlate.id).to eq(original_id)
      end

      it "restores original ID even when block raises error" do
        expect do
          correlate.use(new_id) { raise StandardError, "test error" }
        end.to raise_error(StandardError, "test error")

        expect(correlate.id).to eq(original_id)
      end
    end

    context "when block raises an error" do
      it "ensures cleanup and re-raises the error" do
        expect do
          correlate.use(new_id) { raise ArgumentError, "block error" }
        end.to raise_error(ArgumentError, "block error")
      end
    end
  end

  describe ".call" do
    let(:block_result) { "task executed" }
    let(:test_block) { proc { block_result } }

    before do
      allow(CMDx::Identifier).to receive(:generate).and_return("generated-uuid")
    end

    context "when no id option is provided" do
      context "with no existing correlation ID" do
        it "generates a new correlation ID using Identifier.generate" do
          expect(CMDx::Identifier).to receive(:generate)

          correlate.call(task, &test_block)
        end

        it "sets the generated ID in metadata" do
          correlate.call(task, &test_block)

          expect(metadata[:correlation_id]).to eq("generated-uuid")
        end
      end

      context "with existing correlation ID" do
        before { correlate.id = "existing-id" }

        it "uses the existing correlation ID" do
          expect(CMDx::Identifier).not_to receive(:generate)

          correlate.call(task, &test_block)

          expect(metadata[:correlation_id]).to eq("existing-id")
        end
      end
    end

    context "when id option is a Symbol" do
      let(:method_name) { :id }

      it "calls the method on the task" do
        expect(task).to receive(method_name)

        correlate.call(task, id: method_name, &test_block)
      end

      it "uses the method result as correlation ID" do
        correlate.call(task, id: method_name, &test_block)

        expect(metadata[:correlation_id]).to eq("task-123")
      end
    end

    context "when id option is a Proc" do
      let(:id_proc) { proc { "proc-generated-id" } }

      before do
        allow(task).to receive(:instance_eval).and_yield.and_return("proc-result-id")
      end

      it "evaluates the proc in task context" do
        expect(task).to receive(:instance_eval).and_yield.and_return("proc-result-id")

        correlate.call(task, id: id_proc, &test_block)
      end

      it "uses the proc result as correlation ID" do
        correlate.call(task, id: id_proc, &test_block)

        expect(metadata[:correlation_id]).to eq("proc-result-id")
      end
    end

    context "when id option responds to call" do
      let(:callable) { instance_double("MockCallable", call: "callable-id") }

      it "calls the callable with the task" do
        expect(callable).to receive(:call).with(task)

        correlate.call(task, id: callable, &test_block)
      end

      it "uses the callable result as correlation ID" do
        correlate.call(task, id: callable, &test_block)

        expect(metadata[:correlation_id]).to eq("callable-id")
      end
    end

    context "when id option is a string value" do
      let(:static_id) { "static-correlation-id" }

      it "uses the static value as correlation ID" do
        expect(CMDx::Identifier).not_to receive(:generate)

        correlate.call(task, id: static_id, &test_block)

        expect(metadata[:correlation_id]).to eq(static_id)
      end
    end

    context "when id option is nil" do
      context "with no existing correlation ID" do
        it "generates a new correlation ID" do
          expect(CMDx::Identifier).to receive(:generate)

          correlate.call(task, id: nil, &test_block)

          expect(metadata[:correlation_id]).to eq("generated-uuid")
        end
      end

      context "with existing correlation ID" do
        before { correlate.id = "existing-id" }

        it "uses the existing correlation ID" do
          expect(CMDx::Identifier).not_to receive(:generate)

          correlate.call(task, id: nil, &test_block)

          expect(metadata[:correlation_id]).to eq("existing-id")
        end
      end
    end

    context "when id option is false" do
      it "generates a new correlation ID when falsy value provided" do
        expect(CMDx::Identifier).to receive(:generate)

        correlate.call(task, id: false, &test_block)

        expect(metadata[:correlation_id]).to eq("generated-uuid")
      end
    end

    it "executes the block with the correlation ID set" do
      called_with_id = nil

      correlate.call(task, id: "test-id") do
        called_with_id = correlate.id
      end

      expect(called_with_id).to eq("test-id")
    end

    it "returns the block result" do
      result = correlate.call(task, id: "test-id", &test_block)

      expect(result).to eq(block_result)
    end

    it "restores the original correlation ID after execution" do
      original_id = "original-id"
      correlate.id = original_id

      correlate.call(task, id: "temporary-id", &test_block)

      expect(correlate.id).to eq(original_id)
    end

    context "when block raises an error" do
      let(:error_block) { proc { raise StandardError, "execution error" } }

      it "ensures cleanup and re-raises the error" do
        original_id = "original-id"
        correlate.id = original_id

        expect do
          correlate.call(task, id: "temp-id", &error_block)
        end.to raise_error(StandardError, "execution error")

        expect(correlate.id).to eq(original_id)
      end

      it "still sets the correlation ID in metadata before cleanup" do
        correlate.call(task, id: "error-id") do
          task.result.metadata[:correlation_id] = "error-id"
          raise StandardError, "execution error"
        end
      rescue StandardError
        expect(metadata[:correlation_id]).to eq("error-id")
      end
    end

    context "with conditional execution using 'if'" do
      before do
        allow(task).to receive(:should_correlate?).and_return(true)
      end

      it "applies correlation when 'if' condition is true" do
        correlate.call(task, id: "test-id", if: :should_correlate?, &test_block)

        expect(metadata[:correlation_id]).to eq("test-id")
      end

      it "skips correlation when 'if' condition is false" do
        allow(task).to receive(:should_correlate?).and_return(false)

        result = correlate.call(task, id: "test-id", if: :should_correlate?, &test_block)

        expect(metadata[:correlation_id]).to be_nil

        expect(result).to eq(block_result)
      end
    end

    context "with conditional execution using 'unless'" do
      before do
        allow(task).to receive(:skip_correlation?).and_return(false)
      end

      it "applies correlation when 'unless' condition is false" do
        correlate.call(task, id: "test-id", unless: :skip_correlation?, &test_block)

        expect(metadata[:correlation_id]).to eq("test-id")
      end

      it "skips correlation when 'unless' condition is true" do
        allow(task).to receive(:skip_correlation?).and_return(true)

        result = correlate.call(task, id: "test-id", unless: :skip_correlation?, &test_block)

        expect(metadata[:correlation_id]).to be_nil

        expect(result).to eq(block_result)
      end
    end

    context "with additional options" do
      it "ignores unknown options" do
        expect do
          correlate.call(task, id: "test-id", unknown_option: "value", &test_block)
        end.not_to raise_error
      end
    end
  end
end
