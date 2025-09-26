# frozen_string_literal: true

require "pp"

require_relative "lib/cmdx" unless defined?(CMDx)

def reload!
  exec("irb")
end
