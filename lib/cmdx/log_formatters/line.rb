# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Line

      # TODO: Add color logging to severity:
      # https://github.com/sidekiq/sidekiq/commit/90f83226d893424382aba3f24073ce89f4b93c2e#diff-4b21ac0af44dd61654e41fe70e857785cf96a82c222ada536c3d812be0101452

      def call(severity, time, progname, message)
        message = message.to_h.map { |k, v| "#{k}=#{v}" }.join(" ") if message.is_a?(Result)
        "#{severity[0]}, [#{Utils::DatetimeFormatter.call(time.utc)} ##{Process.pid}] #{severity} -- #{progname || 'CMDx'}: #{message}\n"
      end

    end
  end
end
