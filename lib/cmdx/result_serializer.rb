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
      {
        index: result.index,
        run_id: result.run.id,
        type: result.task.is_a?(Batch) ? "Batch" : "Task",
        class: result.task.class.name,
        id: result.task.id,
        state: result.state,
        status: result.status,
        outcome: result.outcome,
        metadata: result.metadata,
        runtime: result.runtime,
        tags: result.task.task_setting(:tags),
        pid: Process.pid
      }.tap do |hash|
        if result.failed?
          STRIP_FAILURE.call(hash, result, :caused_failure)
          STRIP_FAILURE.call(hash, result, :threw_failure)
        end
      end
    end

  end
end
