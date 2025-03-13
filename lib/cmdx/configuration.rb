# frozen_string_literal: true

module CMDx

  module_function

  def configuration
    @configuration || reset_configuration!
  end

  def configure
    yield(configuration)
  end

  def reset_configuration!
    @configuration = LazyStruct.new(
      logger: ::Logger.new($stdout, formatter: CMDx::LogFormatters::Json.new),
      task_halt: CMDx::Result::FAILED,
      task_timeout: nil,
      batch_halt: CMDx::Result::FAILED,
      batch_timeout: nil
    )
  end

end
