# frozen_string_literal: true

module CMDx
  module Immutator

    module_function

    def call(task)
      # Stubbing on frozen objects is not allowed
      return if (ENV.fetch("RAILS_ENV", nil) || ENV.fetch("RACK_ENV", nil)) == "test"

      task.freeze
      task.result.freeze
      return unless task.result.index.zero?

      task.context.freeze
      task.run.freeze
    end

  end
end
