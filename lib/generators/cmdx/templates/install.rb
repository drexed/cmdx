# frozen_string_literal: true

CMDx.configure do |config|
  # Logger configuration - choose from multiple formatters
  # See https://github.com/drexed/cmdx for more details
  #
  # Available formatters:
  # - CMDx::LogFormatters::Json
  # - CMDx::LogFormatters::KeyValue
  # - CMDx::LogFormatters::Line
  # - CMDx::LogFormatters::Logstash
  # - CMDx::LogFormatters::Raw
  config.logger = Logger.new(
    $stdout,
    progname: "cmdx",
    formatter: CMDx::LogFormatters::Line.new,
    level: Logger::INFO
  )

  # Log level override (optional)
  # config.log_level = :info

  # Log formatter override (optional)
  # config.log_formatter = CMDx::LogFormatters::Line.new
end
