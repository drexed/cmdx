# frozen_string_literal: true

require "pp"

unless defined?(CMDx)
  require_relative "lib/cmdx"

  # rubocop:disable Style/MixinUsage
  require_relative "spec/support/helpers/task_builders"
  require_relative "spec/support/helpers/workflow_builders"
  include CMDx::Testing::TaskBuilders
  include CMDx::Testing::WorkflowBuilders
  # rubocop:enable Style/MixinUsage
end

def reload!
  exec("irb")
end
