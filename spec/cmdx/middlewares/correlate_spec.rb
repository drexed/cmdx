# frozen_string_literal: true

RSpec.describe CMDx::Middlewares::Correlate do
  let(:task_class) do
    Class.new(CMDx::Task) do
      def self.name = "CorrelateTask"
      register :middleware, CMDx::Middlewares::Correlate
      def work; end
    end
  end

  it "sets a correlation_id in context" do
    result = task_class.execute
    expect(result.context[:correlation_id]).to be_a(String)
  end

  it "includes correlation_id in metadata" do
    result = task_class.execute
    expect(result.metadata[:correlation_id]).to be_a(String)
  end
end
