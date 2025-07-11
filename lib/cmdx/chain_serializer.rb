# frozen_string_literal: true

module CMDx
  module ChainSerializer

    module_function

    def call(chain)
      {
        id: chain.id,
        state: chain.state,
        status: chain.status,
        outcome: chain.outcome,
        runtime: chain.runtime,
        results: chain.results.map(&:to_h)
      }
    end

  end
end
