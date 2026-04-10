# frozen_string_literal: true

require "bigdecimal"
require "date"
require "forwardable"
require "json"
require "logger"
require "pathname"
require "securerandom"
require "time"
require "timeout"

require_relative "cmdx/version"
require_relative "cmdx/errors"
require_relative "cmdx/messages"
require_relative "cmdx/callable"
require_relative "cmdx/context"
require_relative "cmdx/error_set"
require_relative "cmdx/result"
require_relative "cmdx/chain"
require_relative "cmdx/coercions"
require_relative "cmdx/validators"
require_relative "cmdx/attribute"
require_relative "cmdx/attribute_set"
require_relative "cmdx/configuration"
require_relative "cmdx/settings"
require_relative "cmdx/callbacks"
require_relative "cmdx/middleware_stack"
require_relative "cmdx/returns"
require_relative "cmdx/task"
require_relative "cmdx/workflow"
require_relative "cmdx/log_entry"
require_relative "cmdx/log_formatters/line"
require_relative "cmdx/log_formatters/json"
require_relative "cmdx/log_formatters/key_value"
require_relative "cmdx/log_formatters/logstash"
require_relative "cmdx/log_formatters/raw"
require_relative "cmdx/middlewares/timeout"
require_relative "cmdx/middlewares/correlate"
require_relative "cmdx/middlewares/runtime"

module CMDx

  EMPTY_ARRAY = [].freeze
  private_constant :EMPTY_ARRAY

  EMPTY_HASH = {}.freeze
  private_constant :EMPTY_HASH

  EMPTY_STRING = ""
  private_constant :EMPTY_STRING

  extend self

  # @return [Pathname]
  def gem_path
    @gem_path ||= Pathname.new(__dir__).parent
  end

  # @return [CMDx::Configuration]
  def configuration
    @configuration ||= Configuration.new
  end

  # @yield [CMDx::Configuration]
  def configure
    yield(configuration)
  end

  # Reset global configuration to defaults.
  # @return [void]
  def reset_configuration!
    @configuration = Configuration.new
  end

  # @return [#call, nil] custom message resolver for i18n integration
  attr_accessor :message_resolver

end
