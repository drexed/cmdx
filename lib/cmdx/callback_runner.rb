# frozen_string_literal: true

module CMDx
  # Invokes definition callbacks for a phase with optional +if+/+unless+.
  class CallbackRunner

    # @param session [Session]
    # @param phase [Symbol]
    # @return [void]
    def self.run(session, phase)
      entries = session.definition.callbacks[phase] || []
      return if entries.empty?

      handler = session.handler
      entries.each do |callable, options|
        next unless Utils::Condition.evaluate(handler, options)

        if callable.is_a?(Symbol)
          handler.send(callable)
        else
          callable.call(session, handler)
        end
      end
    end

  end
end
