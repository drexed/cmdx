# frozen_string_literal: true

module CMDx
  module LogFormatters
    # JSON log formatter for structured logging systems.
    class Json

      # @param data [Hash] structured log data
      # @return [String]
      def call(data)
        sanitized = deep_serialize(data)
        JSON.generate(sanitized)
      end

      private

      def deep_serialize(obj)
        case obj
        when Hash        then obj.transform_values { |v| deep_serialize(v) }
        when Array       then obj.map { |v| deep_serialize(v) }
        when ::Exception then "#{obj.class}: #{obj.message}"
        when Symbol      then obj.to_s
        else obj
        end
      end

    end
  end
end
