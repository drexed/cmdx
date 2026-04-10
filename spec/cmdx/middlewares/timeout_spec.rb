# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middlewares::Timeout do
  let(:slow_class) do
    Class.new(CMDx::Task) do
      register CMDx::Middlewares::Timeout, 0.05

      def work
        sleep 0.2
      end
    end
  end

  let(:fast_class) do
    Class.new(CMDx::Task) do
      register CMDx::Middlewares::Timeout, 1

      def work
        context[:done] = true
      end
    end
  end

  it "yields and completes within the time limit" do
    result = fast_class.execute
    expect(result).to be_success
    expect(result.context[:done]).to be(true)
  end

  it "signals failure when execution exceeds the timeout" do
    result = slow_class.execute
    expect(result).to be_failed
    expect(result.reason).to include("timed out")
    expect(result.reason).to include("0.05")
  end
end
