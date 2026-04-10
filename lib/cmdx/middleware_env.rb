# frozen_string_literal: true

module CMDx
  # Rack-style environment passed through the middleware chain.
  class MiddlewareEnv

    # @return [Session]
    attr_reader :session

    # @return [Task]
    attr_reader :handler

    # @param session [Session]
    # @param handler [Task]
    def initialize(session:, handler:)
      @session = session
      @handler = handler
    end

  end
end
