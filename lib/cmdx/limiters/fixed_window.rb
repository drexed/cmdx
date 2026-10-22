# frozen_string_literal: true

module CMDx
  class Limiters
    # Fixed-window counter using {Stores.incr} with TTL refresh on each hit.
    #
    # @api private
    module FixedWindow

      extend self

      # @param quota [RateLimit::Quota]
      # @return [RateLimit::Admission]
      def call(quota)
        count       = Stores.incr(quota.store_key, ttl: quota.per)
        admitted    = count <= quota.max.to_i
        retry_after = admitted ? nil : Stores.remaining_ttl(quota.store_key)

        RateLimit::Admission.new(
          admitted:,
          count:,
          level: nil,
          retry_after:,
          limiter: :fixed_window
        )
      end

    end
  end
end
