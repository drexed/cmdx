# frozen_string_literal: true

module CMDx
  # Shared store key helpers for store-backed task features ({Idempotency},
  # {CircuitBreaker}, {Lock}, {RateLimit}, and others).
  #
  # {compose} joins colon-separated segments, each coerced with {Stores.key!}.
  # {segment} resolves a per-invocation suffix from a declaration (symbol,
  # proc, callable, or literal).
  module StoreKey

    extend self

    # @param segments [Array<Object>] key segments coerced with {Stores.key!}
    # @return [String] joined key
    # @raise [ArgumentError] when any segment is empty after coercion
    def compose(*segments)
      segments.map! { |s| Stores.key!(s) }.join(":")
    end

    # Resolves a store key segment from a task. Used by {Idempotency},
    # {CircuitBreaker}, and other store-backed declarations.
    #
    # @param task [Task]
    # @param resolver [Symbol, String, Proc, #call]
    # @param skip [Object, nil] when `resolver == skip`, returns `nil` without
    #   reading context (for example `CircuitBreaker::CLASS_KEY`)
    # @return [String, nil] non-empty segment, or `nil` when blank or skipped
    def segment(task, resolver, skip: nil)
      return if skip && resolver == skip

      raw =
        case resolver
        when Symbol
          task.context[resolver]
        when Proc
          task.instance_exec(task, &resolver)
        else
          return resolver.call(task) if resolver.respond_to?(:call)

          resolver
        end

      str = raw&.to_s
      str if str && !str.empty?
    end

  end
end
