# frozen_string_literal: true

module CMDx
  module Freezer

    extend self

    def immute(task)
      # Stubbing on frozen objects is not allowed
      skip_freezing = ENV.fetch("SKIP_CMDX_FREEZING", false)
      return if Coercions::Boolean.call(skip_freezing)

      task.freeze
      task.result.freeze
      return unless task.result.index.zero?

      task.context.freeze
      task.chain.freeze

      Chain.clear
    end

  end
end
