# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middlewares::RuntimeTracker do
  let(:task_class) do
    Class.new(CMDx::Task) do
      register CMDx::Middlewares::RuntimeTracker

      def work
        sleep 0.01
      end
    end
  end

  it "records runtime_ms on the context after execution" do
    result = task_class.execute
    ms = result.context[:runtime_ms]
    expect(ms).to be_a(Numeric)
    expect(ms).to be >= 0
    expect(ms).to be >= 5
  end
end
