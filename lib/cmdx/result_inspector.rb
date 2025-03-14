# frozen_string_literal: true

module CMDx
  module ResultInspector

    ORDERED_KEYS = %i[
      task type index id state status outcome metadata
      tags pid runtime caused_failure threw_failure
    ].freeze

    module_function

    def call(result)
      ORDERED_KEYS.filter_map do |key|
        next unless result.key?(key)

        value = result[key]

        case key
        when :task
          "#{value}:"
        when :caused_failure, :threw_failure
          "#{key}=<[#{value[:index]}] #{value[:task]}: #{value[:id]}>"
        else
          "#{key}=#{value}"
        end
      end.join(" ")
    end

  end
end
