# frozen_string_literal: true

module CMDx
  module ResultInspector

    ORDERED_KEYS = %i[
      class type index id state status outcome metadata
      tags pid runtime caused_failure threw_failure
    ].freeze

    module_function

    def call(result)
      ORDERED_KEYS.filter_map do |key|
        next unless result.key?(key)

        value = result[key]

        case key
        when :class
          "#{value}:"
        when :caused_failure, :threw_failure
          "#{key}=<[#{value[:index]}] #{value[:class]}: #{value[:id]}>"
        else
          "#{key}=#{value}"
        end
      end.join(" ")
    end

  end
end
