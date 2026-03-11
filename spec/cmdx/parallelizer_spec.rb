# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Parallelizer, type: :unit do
  describe ".call" do
    it "processes all items and returns results in order" do
      results = described_class.call([3, 1, 2]) { |n| n * 10 }

      expect(results).to eq([30, 10, 20])
    end

    it "runs items concurrently across threads" do
      mutex = Mutex.new
      thread_ids = []

      described_class.call(%w[a b c]) do |_item|
        mutex.synchronize { thread_ids << Thread.current.object_id }
      end

      expect(thread_ids.size).to eq(3)
    end

    context "with pool_size smaller than item count" do
      it "limits the number of concurrent threads" do
        mutex = Mutex.new
        thread_ids = []

        described_class.call([1, 2, 3, 4], pool_size: 2) do |item|
          mutex.synchronize { thread_ids << Thread.current.object_id }
          item
        end

        expect(thread_ids.uniq.size).to be <= 2
      end

      it "still processes all items" do
        results = described_class.call([1, 2, 3, 4], pool_size: 2) { |n| n + 1 }

        expect(results).to eq([2, 3, 4, 5])
      end
    end

    context "with an empty items array" do
      it "returns an empty array" do
        results = described_class.call([]) { |n| n }

        expect(results).to eq([])
      end
    end
  end

  describe "#call" do
    it "yields each item to the block" do
      yielded = []
      mutex = Mutex.new

      described_class.new(%w[x y z]).call do |item|
        mutex.synchronize { yielded << item }
      end

      expect(yielded).to match_array(%w[x y z])
    end
  end
end
