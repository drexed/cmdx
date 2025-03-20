# frozen_string_literal: true

module CMDx
  module RunSerializer

    module_function

    def call(run)
      {
        id: run.id,
        state: run.state,
        status: run.status,
        outcome: run.outcome,
        runtime: run.runtime,
        results: run.results.map(&:to_h)
      }
    end

  end
end
