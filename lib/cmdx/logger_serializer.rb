# frozen_string_literal: true

module CMDx
  module LoggerSerializer

    COLORED_KEYS = %i[
      state status outcome
    ].freeze

    module_function

    def call(_severity, _time, task, message, **options)
      m = message.respond_to?(:to_h) ? message.to_h : {}

      if options.delete(:ansi_colorize) && message.is_a?(Result)
        COLORED_KEYS.each { |k| m[k] = ResultAnsi.call(m[k]) if m.key?(k) }
      elsif !message.is_a?(Result)
        m.merge!(
          TaskSerializer.call(task),
          message: message
        )
      end

      m[:origin] ||= "CMDx"
      m
    end

  end
end
