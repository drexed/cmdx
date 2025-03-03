# frozen_string_literal: true

module CMDx
  module RunSerializer

    module_function

    def call(run)
      {
        id: run.id,
        results: run.results.map(&:to_h)
      }
    end

  end
end
