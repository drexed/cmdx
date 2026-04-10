# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Minimal raw formatter -- outputs inspect representation only.
    class Raw

      # @param data [Hash] structured log data
      # @return [String]
      def call(data)
        data.inspect
      end

    end
  end
end
