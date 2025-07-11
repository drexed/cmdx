# frozen_string_literal: true

module CMDx
  module TaskSerializer

    module_function

    def call(task)
      {
        index: task.result.index,
        chain_id: task.chain.id,
        type: task.is_a?(Workflow) ? "Workflow" : "Task",
        class: task.class.name,
        id: task.id,
        tags: task.task_setting(:tags)
      }
    end

  end
end
