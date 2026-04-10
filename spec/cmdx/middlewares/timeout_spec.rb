# frozen_string_literal: true

RSpec.describe CMDx::Middlewares::Timeout do
  let(:task_class) do
    Class.new(CMDx::Task) do
      def self.name = "TimeoutTask"
      register :middleware, CMDx::Middlewares::Timeout, seconds: 0.01

      def work
        sleep(1)
      end
    end
  end

  it "fails with timeout message" do
    result = task_class.execute
    expect(result).to be_failed
    expect(result.reason).to include("timed out")
  end
end
