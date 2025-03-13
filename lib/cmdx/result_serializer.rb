# frozen_string_literal: true

module CMDx
  module ResultSerializer

    STRIP_FAILURE = proc do |h, r, k|
      unless r.send(:"#{k}?")
        # Strip caused/threw failures since its the same info as the log line
        h[k] = r.send(k).to_h.except(:caused_failure, :threw_failure)
      end
    end.freeze

    module_function

    def call(result)
      TaskSerializer.call(result.task).tap do |hash|
        hash.merge!(
          state: result.state,
          status: result.status,
          outcome: result.outcome,
          metadata: result.metadata,
          runtime: result.runtime
        )

        if result.failed?
          STRIP_FAILURE.call(hash, result, :caused_failure)
          STRIP_FAILURE.call(hash, result, :threw_failure)
        end
      end
    end

  end
end
