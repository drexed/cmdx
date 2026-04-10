# frozen_string_literal: true

module CMDx
  # Pluggable concurrency; default MRI thread pool preserves submission order.
  module Parallel
    module Threads

      # @param items [Array]
      # @param concurrency [Integer, nil]
      # @yieldparam item [Object]
      # @return [Array]
      def self.call(items, concurrency: nil, &block)
        pool_size = Integer(concurrency || items.size)
        results = Array.new(items.size)
        queue = Queue.new

        items.each_with_index { |item, i| queue << [item, i] }
        pool_size.times { queue << nil }

        Array.new(pool_size) do
          Thread.new do
            while (entry = queue.pop)
              item, index = entry
              results[index] = yield(item)
            end
          end
        end.each(&:join)

        results
      end

    end
  end
end
