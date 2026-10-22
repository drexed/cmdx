# frozen_string_literal: true

module CMDx
  class Limiters
    # Continuous leaky bucket backed by a single store key (`store_key:lb`).
    # Leaks one unit every `per` seconds; admits when `level + cost <= max`.
    #
    # @api private
    module LeakyBucket

      extend self

      # @param quota [RateLimit::Quota]
      # @return [RateLimit::Admission]
      def call(quota)
        state_key = "#{quota.store_key}:lb"
        now       = Time.now.to_f
        level, last_at = parse_state(Stores.get(state_key), now)

        leaked = (now - last_at) / quota.per
        if leaked.positive?
          level -= leaked
          level = 0.0 if level.negative?
        end

        cost      = quota.cost
        capacity  = quota.max
        projected = level + cost
        admitted  = projected <= capacity

        level = projected if admitted

        Stores.set(state_key, "#{level}:#{now}", ttl: bucket_ttl(quota))

        retry_after =
          unless admitted
            overflow = projected - capacity
            overflow = 0 if overflow.negative?
            (overflow * quota.per).ceil
          end

        RateLimit::Admission.new(
          admitted:,
          count: nil,
          level:,
          retry_after:,
          limiter: :leaky_bucket
        )
      end

      private

      def parse_state(raw, now)
        return [0.0, now] if raw.nil? || raw.empty?

        sep = raw.index(":")
        unless sep
          level = Float(raw, exception: false) || 0.0
          return [level, now]
        end

        level   = Float(raw[0, sep], exception: false) || 0.0
        last_at = Float(raw[(sep + 1)..], exception: false) || now
        [level, last_at]
      end

      def bucket_ttl(quota)
        base = quota.max * quota.per
        ttl = base.positive? ? base * 2 : quota.per * 2
        ttl.to_i
      end

    end
  end
end
