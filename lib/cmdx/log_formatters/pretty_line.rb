# frozen_string_literal: true

module CMDx
  module LogFormatters
    class PrettyLine

      COLORED_KEYS = %i[
        state status outcome
      ].freeze
      RESULT_ANSI = proc do |state|
        code =
          case state
          when Result::INITIALIZED then 34                 # Blue
          when Result::EXECUTING, Result::SKIPPED then 33  # Yellow
          when Result::COMPLETE, Result::SUCCESS then 32   # Green
          when Result::INTERRUPTED, Result::FAILED then 31 # Red
          else 39                                          # Default
          end

        "\e[1;#{code}m#{state}\e[0m"
      end.freeze
      SEVERITY_ANSI = proc do |severity|
        code =
          case severity[0]
          when "D" then 34 # DEBUG - Blue
          when "I" then 32 # INFO  - Green
          when "W" then 33 # WARN  - Yellow
          when "E" then 31 # ERROR - Red
          when "F" then 35 # FATAL - Magenta
          else 39          # else  - Default
          end

        "\e[1;#{code}m#{severity}\e[0m"
      end.freeze

      def call(severity, time, progname, message)
        sevw = SEVERITY_ANSI.call(severity)
        sevl = SEVERITY_ANSI.call(severity[0])
        time = Utils::LogTimestamp.call(time.utc)

        if message.is_a?(Result)
          message = message.to_h.map do |k, v|
            v = RESULT_ANSI.call(v) if COLORED_KEYS.include?(k)
            "#{k}=#{v}"
          end.join(" ")
        end

        "#{sevl}, [#{time} ##{Process.pid}] #{sevw} -- #{progname || 'CMDx'}: #{message}\n"
      end

    end
  end
end
