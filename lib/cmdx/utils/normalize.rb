# frozen_string_literal: true

module CMDx
  module Utils
    # Provides normalization utilities for a variety of objects
    # into consistent formats.
    module Normalize

      extend self

      # Normalizes an exception into a string representation.
      #
      # @param exception [Exception] The exception to normalize
      #
      # @return [String] The normalized exception string
      #
      # @example From exception
      #   Normalize.exception(StandardError.new("test"))
      #   # => "[StandardError] test"
      #
      # @rbs (Exception exception) -> String
      def exception(exception)
        "[#{exception.class}] #{exception.message}"
      end

      # Normalizes an object into an array of unique status strings.
      #
      # @param object [Object] The object to normalize into status strings
      #
      # @return [Array<String>] Unique status strings
      #
      # @example From array of symbols
      #   Normalize.statuses([:success, :pending, :success])
      #   # => ["success", "pending"]
      # @example From single value
      #   Normalize.statuses(:success)
      #   # => ["success"]
      # @example From nil
      #   Normalize.statuses(nil)
      #   # => []
      #
      # @rbs (untyped object) -> Array[String]
      def statuses(object)
        Wrap.array(object).map(&:to_s).uniq
      end

    end
  end
end
