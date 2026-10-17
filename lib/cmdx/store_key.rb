# frozen_string_literal: true

module CMDx
  # Builds colon-separated store keys with the same non-empty coercion as
  # {Stores.key!}. Used by {Idempotency} (`namespace:TaskName:segment`) and
  # other store-backed helpers.
  module StoreKey

    extend self

    # @param segments [Array<Object>] key segments coerced with {Stores.key!}
    # @return [String] joined key
    # @raise [ArgumentError] when any segment is empty after coercion
    def compose(*segments)
      segments.map { |segment| Stores.key!(segment) }.join(":")
    end

  end
end
