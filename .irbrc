# frozen_string_literal: true

require "pp"

# rubocop:disable-next Style/MixinUsage
unless defined?(CMDx)
  require_relative "lib/cmdx"

  require_relative "spec/support/helpers/task_builders"
  require_relative "spec/support/helpers/workflow_builders"
  include CMDx::Testing::TaskBuilders
  include CMDx::Testing::WorkflowBuilders
end

def reload!
  exec("irb")
end
