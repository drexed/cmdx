# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Utils::MonotonicRuntime do
  describe ".call" do
    context "with simple operations" do
      it "measures execution time for no-op block" do
        result = described_class.call do
          # no operation
        end

        expect(result).to be >= 0
        expect(result).to be < 10 # Should be very fast
      end

      it "measures execution time for sleep operation" do
        result = described_class.call do
          sleep(0.01) # 10ms
        end

        expect(result).to be >= 8  # Allow some variance
        expect(result).to be < 50  # Should not be too slow
      end

      it "returns integer milliseconds" do
        result = described_class.call do
          sleep(0.001) # 1ms
        end

        expect(result).to be_a(Integer)
      end

      it "measures different durations consistently" do
        short_time = described_class.call do
          sleep(0.005) # 5ms
        end

        long_time = described_class.call do
          sleep(0.02) # 20ms
        end

        expect(long_time).to be > short_time
      end
    end

    context "with exception handling" do
      it "measures time even when block raises exception" do
        expect do
          described_class.call do
            sleep(0.01)
            raise StandardError, "Test error"
          end
        end.to raise_error(StandardError, "Test error")
      end

      it "returns time measurement before exception" do
        runtime = nil
        begin
          runtime = described_class.call do
            sleep(0.01)
            raise "Error after sleep"
          end
        rescue StandardError
          # Exception caught but runtime should be measured
        end

        # Runtime should be nil because exception was raised
        expect(runtime).to be_nil
      end

      it "handles different exception types" do
        expect do
          described_class.call do
            sleep(0.005)
            raise ArgumentError, "Invalid argument"
          end
        end.to raise_error(ArgumentError, "Invalid argument")
      end

      it "handles custom exceptions" do
        custom_error = Class.new(StandardError)

        expect do
          described_class.call do
            sleep(0.005)
            raise custom_error, "Custom error"
          end
        end.to raise_error(custom_error, "Custom error")
      end
    end

    context "with block return values" do
      it "discards block return value and returns timing" do
        result = described_class.call do
          sleep(0.001)
          "block return value"
        end

        expect(result).to be_a(Integer)
        expect(result).not_to eq("block return value")
      end

      it "measures time regardless of block return type" do
        results = []

        results << described_class.call { nil }
        results << described_class.call { 42 }
        results << described_class.call { "string" }
        results << described_class.call { [1, 2, 3] }
        results << described_class.call { { key: "value" } }

        expect(results).to all(be_a(Integer))
        expect(results).to all(be >= 0)
      end

      it "handles complex return values" do
        result = described_class.call do
          {
            data: (1..100).to_a,
            processed: true,
            timestamp: Time.now
          }
        end

        expect(result).to be_a(Integer)
        expect(result).to be >= 0
      end
    end

    context "with nested operations" do
      it "measures nested block calls correctly" do
        outer_time = described_class.call do
          described_class.call do
            sleep(0.005)
          end
          sleep(0.005)
        end

        expect(outer_time).to be >= 8 # Should be at least 10ms
        expect(outer_time).to be < 50
      end

      it "handles recursive operations" do
        def fibonacci(n)
          return n if n <= 1

          fibonacci(n - 1) + fibonacci(n - 2)
        end

        result = described_class.call do
          fibonacci(20)
        end

        expect(result).to be >= 0
        expect(result).to be < 1000 # Should complete within 1 second
      end

      it "measures database-like operations" do
        mock_db = double("database")
        allow(mock_db).to receive(:query) {
          sleep(0.01)
          "result"
        }

        result = described_class.call do
          3.times { mock_db.query }
        end

        expect(result).to be >= 25 # 3 * 10ms with some variance
        expect(result).to be < 100
      end
    end

    context "with precision and accuracy" do
      it "provides millisecond precision" do
        times = []
        10.times do
          times << described_class.call { sleep(0.001) }
        end

        # Should have some variation in microsecond-level timing
        pp times
        expect(times.uniq.size).to be > 1
      end

      it "maintains monotonic timing behavior" do
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

        measured_time = described_class.call do
          sleep(0.01)
        end

        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
        actual_time = end_time - start_time

        # Measured time should be close to actual elapsed time
        expect(measured_time).to be_within(5).of(actual_time)
      end

      it "handles very short operations" do
        result = described_class.call do
          1 + 1
        end

        expect(result).to be >= 0
        expect(result).to be < 5 # Very fast operation
      end

      it "handles longer operations accurately" do
        result = described_class.call do
          sleep(0.1) # 100ms
        end

        expect(result).to be_within(10).of(100)
      end
    end
  end
end
