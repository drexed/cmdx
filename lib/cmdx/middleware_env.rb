# frozen_string_literal: true

module CMDx
  # Rack-style environment passed through the middleware chain.
  # Provides clean access to session metadata without exposing task internals.
  class MiddlewareEnv

    # @return [Session]
    attr_reader :session

    # @return [Task]
    attr_reader :task

    # @param session [Session]
    # @param task [Task]
    #
    # @rbs (session: Session, task: Task) -> void
    def initialize(session:, task:)
      @session = session
      @task = task
    end

  end
end
