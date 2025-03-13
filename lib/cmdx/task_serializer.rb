# frozen_string_literal: true

module CMDx
  module TaskSerializer

    module_function

    def call(task)
      {
        index: task.result.index,
        run_id: task.run.id,
        type: task.is_a?(Batch) ? "Batch" : "Task",
        task: task.class.name,
        id: task.id,
        tags: task.task_setting(:tags)
      }
    end

  end
end
