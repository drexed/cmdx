# frozen_string_literal: true

RSpec.describe CMDx::Deprecators::Log do
  describe ".call" do
    let(:log_output) { StringIO.new }
    let(:logger) { Logger.new(log_output) }
    let(:task) do
      log = logger
      Class.new do
        define_method(:logger) { log }
      end.new
    end

    it "writes a deprecation warning via the task logger" do
      described_class.call(task)

      expect(log_output.string).to include("DEPRECATED:", task.class.to_s)
    end
  end
end
