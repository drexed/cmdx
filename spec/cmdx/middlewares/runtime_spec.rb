# frozen_string_literal: true

RSpec.describe CMDx::Middlewares::Runtime do
  before { CMDx.configuration.freeze_results = false }

  it "records runtime metadata" do
    klass = Class.new(CMDx::Task) do
      register :middleware, CMDx::Middlewares::Runtime

      def work
        context.done = true
      end
    end

    result = klass.execute
    expect(result).to be_success
    expect(result.metadata).to have_key(:runtime)
    expect(result.metadata).to have_key(:started_at)
    expect(result.metadata).to have_key(:ended_at)
    expect(result.metadata[:runtime]).to be_a(Integer)
  end
end
