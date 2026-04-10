# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Configuration do
  describe "defaults" do
    before { CMDx.reset_configuration! }

    it "uses a Logger writing to $stdout" do
      log = CMDx.configuration.logger
      expect(log).to be_a(Logger)
      expect(log.instance_variable_get(:@logdev).dev).to eq($stdout)
    end

    it "defaults log_level, log_formatter to nil and strict_attributes to true" do
      c = CMDx.configuration
      expect(c.log_level).to be_nil
      expect(c.log_formatter).to be_nil
      expect(c.strict_attributes).to be(true)
    end
  end

  describe "mutators" do
    let(:custom_logger) { Logger.new(File::NULL) }
    let(:formatter) { proc { |_, _, _, msg| "#{msg}\n" } }

    it "assigns logger, log_level, log_formatter, and strict_attributes" do
      CMDx.configuration.logger = custom_logger
      CMDx.configuration.log_level = :warn
      CMDx.configuration.log_formatter = formatter
      CMDx.configuration.strict_attributes = false

      c = CMDx.configuration
      expect(c.logger).to be(custom_logger)
      expect(c.log_level).to eq(:warn)
      expect(c.log_formatter).to be(formatter)
      expect(c.strict_attributes).to be(false)
    end
  end

  describe ".configure" do
    it "yields the global configuration and returns it" do
      yielded = nil
      ret = CMDx.configure do |c|
        yielded = c
        c.log_level = :error
      end

      expect(yielded).to be(CMDx.configuration)
      expect(ret).to be(CMDx.configuration)
      expect(CMDx.configuration.log_level).to eq(:error)
    end
  end

  describe "CMDx.reset_configuration!" do
    it "restores defaults" do
      CMDx.configure do |c|
        c.logger = Logger.new(File::NULL)
        c.log_level = :fatal
        c.log_formatter = proc { |_| }
        c.strict_attributes = false
      end

      CMDx.reset_configuration!

      c = CMDx.configuration
      expect(c.logger).to be_a(Logger)
      expect(c.logger.instance_variable_get(:@logdev).dev).to eq($stdout)
      expect(c.log_level).to be_nil
      expect(c.log_formatter).to be_nil
      expect(c.strict_attributes).to be(true)
    end
  end
end
