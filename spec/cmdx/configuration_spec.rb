# frozen_string_literal: true

RSpec.describe CMDx::Configuration do
  subject(:config) { described_class.new }

  it "has sane defaults" do
    expect(config.logger).to be_a(Logger)
    expect(config.log_level).to eq(:info)
    expect(config.task_breakpoints).to eq(%w[failed])
    expect(config.rollback_on).to eq(%w[failed])
    expect(config.middlewares).to eq([])
    expect(config.coercions).to eq({})
    expect(config.validators).to eq({})
  end

  describe "#reset!" do
    it "restores all defaults" do
      config.log_level = :debug
      config.task_breakpoints = %w[failed skipped]
      config.reset!
      expect(config.log_level).to eq(:info)
      expect(config.task_breakpoints).to eq(%w[failed])
    end
  end
end
