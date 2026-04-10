# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Task do
  let(:task_class) do
    Class.new(described_class) do
      required :name, type: :string, presence: true

      def work
        context[:greeting] = "Hello, #{name}!"
      end
    end
  end

  describe ".execute" do
    it "returns success with coerced context" do
      result = task_class.execute(name: "World")
      expect(result.success?).to be true
      expect(result.context[:greeting]).to eq("Hello, World!")
    end

    it "fails validation on blank name" do
      result = task_class.execute(name: "   ")
      expect(result.failed?).to be true
    end
  end

  describe ".execute!" do
    it "raises FailFault on failure" do
      expect { task_class.execute!(name: "") }.to raise_error(CMDx::FailFault)
    end
  end
end
