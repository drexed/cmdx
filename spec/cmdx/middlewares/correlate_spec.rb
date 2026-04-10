# frozen_string_literal: true

RSpec.describe CMDx::Middlewares::Correlate do
  before { CMDx.configuration.freeze_results = false }

  after { described_class.clear }

  it "adds a correlation ID" do
    klass = Class.new(CMDx::Task) do
      register :middleware, CMDx::Middlewares::Correlate

      def work; end
    end

    result = klass.execute
    expect(result.metadata[:correlation_id]).to be_a(String)
    expect(result.metadata[:correlation_id]).not_to be_empty
  end

  it "reuses existing correlation ID" do
    klass = Class.new(CMDx::Task) do
      register :middleware, CMDx::Middlewares::Correlate

      def work; end
    end

    described_class.use("my-trace-id") do
      result = klass.execute
      expect(result.metadata[:correlation_id]).to eq("my-trace-id")
    end
  end

  describe ".use" do
    it "scopes and restores the correlation ID" do
      described_class.id = "outer"

      described_class.use("inner") do
        expect(described_class.id).to eq("inner")
      end

      expect(described_class.id).to eq("outer")
    end
  end
end
