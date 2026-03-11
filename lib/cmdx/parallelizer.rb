# frozen_string_literal: true

module CMDx
  # Bounded thread pool that processes items concurrently.
  #
  # Distributes work across a fixed number of threads using a queue,
  # collecting results in submission order.
  class Parallelizer

    # Returns the items to process.
    #
    # @return [Array] the items to process
    #
    # @example
    #   parallelizer.items # => [1, 2, 3]
    #
    # @rbs @items: Array[untyped]
    attr_reader :items

    # Returns the number of threads in the pool.
    #
    # @return [Integer] the thread pool size
    #
    # @example
    #   parallelizer.pool_size # => 4
    #
    # @rbs @pool_size: Integer
    attr_reader :pool_size

    # Creates a new Parallelizer instance.
    #
    # @param items [Array] the items to process concurrently
    # @param pool_size [Integer] number of threads (defaults to item count)
    #
    # @return [Parallelizer] a new parallelizer instance
    #
    # @example
    #   Parallelizer.new([1, 2, 3], pool_size: 2)
    #
    # @rbs (Array[untyped] items, ?pool_size: Integer) -> void
    def initialize(items, pool_size: nil)
      @items = items
      @pool_size = Integer(pool_size || items.size)
    end

    # Processes items concurrently and returns results in submission order.
    #
    # @param items [Array] the items to process concurrently
    # @param pool_size [Integer] number of threads (defaults to item count)
    #
    # @yield [item] block called for each item in a worker thread
    # @yieldparam item [Object] an item from the items array
    # @yieldreturn [Object] the result for this item
    #
    # @return [Array] results in the same order as input items
    #
    # @example
    #   Parallelizer.call([1, 2, 3], pool_size: 2) { |n| n * 10 }
    #   # => [10, 20, 30]
    #
    # @rbs [T, R] (Array[T] items, ?pool_size: Integer) { (T) -> R } -> Array[R]
    def self.call(items, pool_size: nil, &block)
      new(items, pool_size:).call(&block)
    end

    # Distributes items across the thread pool and returns results
    # in submission order.
    #
    # @yield [item] block called for each item in a worker thread
    # @yieldparam item [Object] an item from the items array
    # @yieldreturn [Object] the result for this item
    #
    # @return [Array] results in the same order as input items
    #
    # @example
    #   Parallelizer.new(%w[a b c]).call { |s| s.upcase }
    #   # => ["A", "B", "C"]
    #
    # @rbs [T, R] () { (T) -> R } -> Array[R]
    def call(&block)
      results = Array.new(items.size)
      queue = Queue.new

      items.each_with_index { |item, i| queue << [item, i] }
      pool_size.times { queue << nil }

      Array.new(pool_size) do
        Thread.new do
          while (entry = queue.pop)
            item, index = entry
            results[index] = block.call(item) # rubocop:disable Performance/RedundantBlockCall
          end
        end
      end.each(&:join)

      results
    end

  end
end
