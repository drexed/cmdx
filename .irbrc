# frozen_string_literal: true

require "pp"

# rubocop:disable Style/MixinUsage
unless defined?(CMDx)
  require_relative "lib/cmdx"

  require_relative "spec/support/helpers/task_builders"
  require_relative "spec/support/helpers/workflow_builders"
  include CMDx::Testing::TaskBuilders
  include CMDx::Testing::WorkflowBuilders
end
# rubocop:enable Style/MixinUsage

def reload!
  exec("irb")
end
