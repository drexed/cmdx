# frozen_string_literal: true

module CMDx
  # Bounded thread pool for parallel task execution.
  class Parallelizer

    # @return [Integer] maximum concurrent threads
    # @rbs @pool_size: Integer
    attr_reader :pool_size

    # @param pool_size [Integer] maximum concurrent threads
    #
    # @rbs (?Integer pool_size) -> void
    def initialize(pool_size = 5)
      @pool_size = pool_size
    end

    # Executes work items in parallel with bounded concurrency.
    #
    # @param items [Array] items to process
    # @yield [item] block to execute per item
    #
    # @return [Array] results in order
    #
    # @rbs (Array[untyped] items) { (untyped) -> untyped } -> Array[untyped]
    def call(items, &block)
      return [] if items.empty?
      return items.map(&block) if items.size == 1

      queue = Queue.new
      items.each_with_index { |item, i| queue << [item, i] }

      results = ::Array.new(items.size)
      errors = []
      mutex = Mutex.new
      n_threads = [pool_size, items.size].min

      workers = Array.new(n_threads) do
        Thread.new do
          loop do
            item, idx =
              begin
                queue.pop(true)
              rescue ThreadError
                break
              end
            begin
              results[idx] = block.call(item) # rubocop:disable Performance/RedundantBlockCall
            rescue StandardError => e
              mutex.synchronize { errors << e }
            end
          end
        end
      end

      workers.each(&:join)
      raise errors.first if errors.any?

      results
    end

  end
end
