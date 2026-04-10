# frozen_string_literal: true

require "spec_helper"

RSpec.describe "CMDx::Workflow" do
  let(:step_one) do
    Class.new(CMDx::Task) do
      def work
        context[:step] = 1
      end
    end
  end

  let(:step_two) do
    Class.new(CMDx::Task) do
      def work
        context[:step] = context[:step].to_i + 1
      end
    end
  end

  let(:flow_class) do
    s1 = step_one
    s2 = step_two
    Class.new(CMDx::Task) do
      include CMDx::Workflow

      task s1, s2
    end
  end

  it "runs steps in order sharing context" do
    result = flow_class.execute
    expect(result.success?).to be true
    expect(result.context[:step]).to eq(2)
  end
end
