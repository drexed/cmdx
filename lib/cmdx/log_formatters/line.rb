# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Default single-line log formatter.
    class Line

      # @param data [Hash] structured log data
      # @return [String]
      def call(data)
        data.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
      end

    end
  end
end
