# frozen_string_literal: true

RSpec.describe CMDx::Middlewares::RuntimeTracker do
  let(:task_class) do
    Class.new(CMDx::Task) do
      def self.name = "TrackedTask"
      register :middleware, CMDx::Middlewares::RuntimeTracker
      def work; end
    end
  end

  it "records runtime_ms in metadata" do
    result = task_class.execute
    expect(result.metadata[:runtime_ms]).to be_a(Numeric)
    expect(result.metadata[:started_at]).to be_a(String)
  end
end
