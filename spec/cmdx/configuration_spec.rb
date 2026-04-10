# frozen_string_literal: true

RSpec.describe CMDx::Configuration do
  subject(:config) { described_class.new }

  it "has sensible defaults" do
    expect(config.task_breakpoints).to eq(%w[failed])
    expect(config.workflow_breakpoints).to eq(%w[failed])
    expect(config.rollback_on).to eq(%w[failed])
    expect(config.dump_context).to be(false)
    expect(config.freeze_results).to be(true)
    expect(config.backtrace).to be(false)
    expect(config.exception_handler).to be_nil
    expect(config.logger).to be_a(Logger)
  end

  it "is configurable" do
    config.task_breakpoints = %w[skipped failed]
    expect(config.task_breakpoints).to eq(%w[skipped failed])
  end

  describe "CMDx.configure" do
    it "yields configuration" do
      CMDx.configure do |c|
        c.dump_context = true
      end

      expect(CMDx.configuration.dump_context).to be(true)
    end
  end

  describe "CMDx.reset_configuration!" do
    it "resets to defaults" do
      CMDx.configuration.dump_context = true
      CMDx.reset_configuration!
      CMDx.configuration.logger = Logger.new(nil)
      expect(CMDx.configuration.dump_context).to be(false)
    end
  end
end
