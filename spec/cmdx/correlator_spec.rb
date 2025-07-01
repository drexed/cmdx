# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Correlator do
  after do
    # Clean up correlation state after each test to prevent interference
    described_class.clear
  end

  describe ".generate" do
    it "returns a UUID string" do
      result = described_class.generate

      expect(result).to be_a(String)
      expect(result).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it "generates unique UUIDs on subsequent calls" do
      uuid1 = described_class.generate
      uuid2 = described_class.generate

      expect(uuid1).not_to eq(uuid2)
    end

    it "generates RFC 4122 compliant UUIDs" do
      uuid = described_class.generate

      expect(uuid.length).to eq(36)
      expect(uuid.count("-")).to eq(4)
    end

    it "generates different UUIDs across multiple calls" do
      uuids = Array.new(10) { described_class.generate }

      expect(uuids.uniq.length).to eq(10)
    end
  end

  describe ".id" do
    context "when no correlation ID is set" do
      it "returns nil" do
        expect(described_class.id).to be_nil
      end
    end

    context "when correlation ID has been set" do
      before do
        described_class.id = "test-correlation-123"
      end

      it "returns the set correlation ID" do
        expect(described_class.id).to eq("test-correlation-123")
      end
    end

    context "when correlation ID has been cleared" do
      before do
        described_class.id = "temporary-id"
        described_class.clear
      end

      it "returns nil" do
        expect(described_class.id).to be_nil
      end
    end
  end

  describe ".id=" do
    it "sets the correlation ID for the current thread" do
      described_class.id = "new-correlation-id"

      expect(described_class.id).to eq("new-correlation-id")
    end

    it "overwrites existing correlation ID" do
      described_class.id = "first-id"
      described_class.id = "second-id"

      expect(described_class.id).to eq("second-id")
    end

    it "accepts string values" do
      described_class.id = "string-correlation"

      expect(described_class.id).to eq("string-correlation")
    end

    it "accepts numeric values" do
      described_class.id = 12_345

      expect(described_class.id).to eq(12_345)
    end

    it "accepts symbol values" do
      described_class.id = :symbol_correlation

      expect(described_class.id).to eq(:symbol_correlation)
    end

    it "returns the assigned value" do
      result = described_class.id = "returned-value"

      expect(result).to eq("returned-value")
    end

    it "stores nil values" do
      described_class.id = "something"
      described_class.id = nil

      expect(described_class.id).to be_nil
    end
  end

  describe ".clear" do
    context "when correlation ID is set" do
      before do
        described_class.id = "correlation-to-clear"
      end

      it "clears the correlation ID" do
        described_class.clear

        expect(described_class.id).to be_nil
      end

      it "returns nil" do
        result = described_class.clear

        expect(result).to be_nil
      end
    end

    context "when no correlation ID is set" do
      it "returns nil" do
        result = described_class.clear

        expect(result).to be_nil
      end

      it "leaves correlation state as nil" do
        described_class.clear

        expect(described_class.id).to be_nil
      end
    end

    context "when called multiple times" do
      before do
        described_class.id = "test-id"
      end

      it "remains safe to call repeatedly" do
        described_class.clear
        described_class.clear
        described_class.clear

        expect(described_class.id).to be_nil
      end
    end
  end

  describe ".use" do
    context "when given a string value" do
      it "sets correlation ID for the duration of the block" do
        described_class.use("block-correlation") do
          expect(described_class.id).to eq("block-correlation")
        end
      end

      it "restores previous correlation ID after block" do
        described_class.id = "original-id"

        described_class.use("temporary-id") do
          # Block execution
        end

        expect(described_class.id).to eq("original-id")
      end

      it "returns the block's return value" do
        result = described_class.use("test-id") do
          "block-result"
        end

        expect(result).to eq("block-result")
      end
    end

    context "when given a symbol value" do
      it "accepts symbol correlation IDs" do
        described_class.use(:symbol_correlation) do
          expect(described_class.id).to eq(:symbol_correlation)
        end
      end

      it "restores previous state after symbol correlation" do
        described_class.id = "original"

        described_class.use(:temp_symbol) do
          # Block execution
        end

        expect(described_class.id).to eq("original")
      end
    end

    context "when given invalid type" do
      it "raises TypeError for numeric values" do
        expect do
          described_class.use(12_345) do
            # Block should not execute
          end
        end.to raise_error(TypeError, "must be a String or Symbol")
      end

      it "raises TypeError for array values" do
        expect do
          described_class.use(["array"]) do
            # Block should not execute
          end
        end.to raise_error(TypeError, "must be a String or Symbol")
      end

      it "raises TypeError for hash values" do
        expect do
          described_class.use({ key: "value" }) do
            # Block should not execute
          end
        end.to raise_error(TypeError, "must be a String or Symbol")
      end

      it "raises TypeError for nil values" do
        expect do
          described_class.use(nil) do
            # Block should not execute
          end
        end.to raise_error(TypeError, "must be a String or Symbol")
      end
    end

    context "when block raises an exception" do
      before do
        described_class.id = "original-before-exception"
      end

      it "restores original correlation ID even when block raises" do
        begin
          described_class.use("exception-context") do
            raise StandardError, "test exception"
          end
        rescue StandardError
          # Exception handled
        end

        expect(described_class.id).to eq("original-before-exception")
      end

      it "propagates the exception" do
        expect do
          described_class.use("error-context") do
            raise ArgumentError, "test error"
          end
        end.to raise_error(ArgumentError, "test error")
      end

      it "handles multiple exception types" do
        [StandardError, RuntimeError, ArgumentError, NoMethodError].each do |exception_class|
          described_class.id = "pre-exception"

          begin
            described_class.use("exception-test") do
              raise exception_class, "test"
            end
          rescue exception_class
            # Expected exception
          end

          expect(described_class.id).to eq("pre-exception")
        end
      end
    end

    context "when nesting correlation contexts" do
      it "supports nested correlation contexts" do
        correlation_ids = []

        described_class.use("outer") do
          correlation_ids << described_class.id

          described_class.use("inner") do
            correlation_ids << described_class.id
          end

          correlation_ids << described_class.id
        end

        expect(correlation_ids).to eq(%w[outer inner outer])
      end

      it "restores proper context after deeply nested calls" do
        described_class.id = "root"

        described_class.use("level-1") do
          described_class.use("level-2") do
            described_class.use("level-3") do
              expect(described_class.id).to eq("level-3")
            end
            expect(described_class.id).to eq("level-2")
          end
          expect(described_class.id).to eq("level-1")
        end

        expect(described_class.id).to eq("root")
      end

      it "handles exceptions in nested contexts" do
        described_class.id = "original"

        begin
          described_class.use("outer") do
            described_class.use("inner") do
              raise StandardError, "nested exception"
            end
          end
        rescue StandardError
          # Exception handled
        end

        expect(described_class.id).to eq("original")
      end

      it "supports mixed string and symbol nesting" do
        described_class.use("string-outer") do
          described_class.use(:symbol_inner) do
            expect(described_class.id).to eq(:symbol_inner)
          end
          expect(described_class.id).to eq("string-outer")
        end
      end
    end

    context "when no previous correlation ID exists" do
      it "sets correlation ID from nil state" do
        expect(described_class.id).to be_nil

        described_class.use("new-correlation") do
          expect(described_class.id).to eq("new-correlation")
        end

        expect(described_class.id).to be_nil
      end

      it "returns to nil state after block completion" do
        described_class.use("temporary") do
          described_class.id = "modified-inside"
        end

        expect(described_class.id).to be_nil
      end
    end
  end

  describe "thread safety" do
    it "maintains separate correlation IDs across threads" do
      other_thread_id = nil
      threads_completed = 0

      described_class.id = "main-thread-correlation"

      thread = Thread.new do
        described_class.id = "other-thread-correlation"
        other_thread_id = described_class.id
        threads_completed += 1
      end

      thread.join
      main_thread_id = described_class.id

      expect(main_thread_id).to eq("main-thread-correlation")
      expect(other_thread_id).to eq("other-thread-correlation")
      expect(threads_completed).to eq(1)
    end

    it "does not interfere with correlation contexts across threads" do
      results = {}
      threads = []

      3.times do |i|
        threads << Thread.new do
          correlation_id = "thread-#{i}-correlation"
          described_class.use(correlation_id) do
            # Simulate some work
            sleep(0.01)
            results[Thread.current.object_id] = described_class.id
          end
        end
      end

      threads.each(&:join)

      expect(results.values.uniq.length).to eq(3)
      expect(results.values).to include("thread-0-correlation", "thread-1-correlation", "thread-2-correlation")
    end

    it "clears correlation ID independently per thread" do
      other_cleared = false

      described_class.id = "main-thread"

      thread = Thread.new do
        described_class.id = "other-thread"
        described_class.clear
        other_cleared = described_class.id.nil?
      end

      thread.join
      described_class.clear
      main_cleared = described_class.id.nil?

      expect(main_cleared).to be(true)
      expect(other_cleared).to be(true)
    end
  end

  describe "integration scenarios" do
    context "when simulating request processing" do
      it "maintains correlation across multiple operations" do
        correlation_operations = []

        described_class.use("request-abc123") do
          correlation_operations << [:start, described_class.id]

          # Simulate nested service calls
          described_class.use("service-call-1") do
            correlation_operations << [:service_1, described_class.id]
          end

          correlation_operations << [:between_services, described_class.id]

          described_class.use("service-call-2") do
            correlation_operations << [:service_2, described_class.id]
          end

          correlation_operations << [:end, described_class.id]
        end

        expected_operations = [
          [:start, "request-abc123"],
          [:service_1, "service-call-1"],
          [:between_services, "request-abc123"],
          [:service_2, "service-call-2"],
          [:end, "request-abc123"]
        ]

        expect(correlation_operations).to eq(expected_operations)
      end

      it "handles error scenarios gracefully" do
        operations = []

        begin
          described_class.use("error-prone-request") do
            operations << [:start, described_class.id]

            described_class.use("failing-operation") do
              operations << [:before_error, described_class.id]
              raise StandardError, "simulated failure"
            end
          end
        rescue StandardError
          operations << [:after_error, described_class.id]
        end

        expect(operations).to eq([
                                   [:start, "error-prone-request"],
                                   [:before_error, "failing-operation"],
                                   [:after_error, nil]
                                 ])
      end
    end

    context "when managing batch operations" do
      it "supports batch correlation with individual item contexts" do
        batch_results = []

        described_class.use("batch-operation-456") do
          batch_results << [:batch_start, described_class.id]

          %w[item-1 item-2 item-3].each do |item|
            described_class.use("#{item}-processing") do
              batch_results << [:item, described_class.id]
            end
            batch_results << [:item_complete, described_class.id]
          end

          batch_results << [:batch_end, described_class.id]
        end

        expected_results = [
          [:batch_start, "batch-operation-456"],
          [:item, "item-1-processing"],
          [:item_complete, "batch-operation-456"],
          [:item, "item-2-processing"],
          [:item_complete, "batch-operation-456"],
          [:item, "item-3-processing"],
          [:item_complete, "batch-operation-456"],
          [:batch_end, "batch-operation-456"]
        ]

        expect(batch_results).to eq(expected_results)
      end
    end

    context "when correlation IDs are generated dynamically" do
      it "can use generated UUIDs as correlation IDs" do
        generated_id = described_class.generate
        used_id = nil

        described_class.use(generated_id) do
          used_id = described_class.id
        end

        expect(used_id).to eq(generated_id)
        expect(used_id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end

      it "supports correlation ID generation within context" do
        outer_id = described_class.generate
        inner_id = nil

        described_class.use(outer_id) do
          inner_id = described_class.generate
          described_class.use(inner_id) do
            expect(described_class.id).to eq(inner_id)
            expect(described_class.id).not_to eq(outer_id)
          end
        end

        expect(inner_id).not_to eq(outer_id)
      end
    end
  end
end
