# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::CallbackRegistry do
  let(:registry) { described_class.new }

  let(:result) do
    CMDx::Result.new(
      task_id: "tid",
      task_class: nil,
      task_type: "spec",
      task_tags: [],
      state: "complete",
      status: "success",
      reason: nil,
      cause: nil,
      metadata: {},
      strict: true,
      retries: 0,
      rolled_back: false,
      context: CMDx::Context.new,
      chain: nil,
      errors: CMDx::Errors.new,
      index: 0
    )
  end

  describe "#register and #for_type" do
    it "stores callbacks for a type" do
      registry.register(:on_success, :record)
      expect(registry.for_type(:on_success).size).to eq(1)
      expect(registry.for_type(:on_success).first[:callable]).to eq(:record)
    end
  end

  describe "#invoke" do
    let(:task_class) do
      Class.new do
        attr_reader :events

        def initialize
          @events = []
        end

        def record
          @events << :record
        end

        def track(result)
          @events << [:track, result]
        end
      end
    end

    it "invokes all callbacks for a type using Utils::Call.invoke_callback" do
      task = task_class.new
      registry.register(:on_success, :record)
      registry.register(:on_success, ->(r) { track(r) })

      registry.invoke(:on_success, task, result)

      expect(task.events).to eq([:record, [:track, result]])
    end

    it "filters with :if using Utils::Condition.truthy?" do
      task = task_class.new
      def task.allow?
        false
      end

      registry.register(:on_success, :record, if: :allow?)
      registry.register(:on_success, :record)

      registry.invoke(:on_success, task, result)
      expect(task.events).to eq([:record])
    end

    it "filters with :unless using Utils::Condition.falsy?" do
      task = task_class.new
      def task.block?
        true
      end

      registry.register(:on_success, :record, unless: :block?)

      registry.invoke(:on_success, task, result)
      expect(task.events).to eq([])
    end
  end

  describe "#any?" do
    it "is false when empty and true after register" do
      expect(registry.any?).to be(false)
      registry.register(:before_validation, proc {})
      expect(registry.any?).to be(true)
    end
  end

  describe "#for_child" do
    it "duplicates callbacks for copy-on-write" do
      registry.register(:on_failed, proc {})

      child = registry.for_child
      child.register(:on_failed, proc {})

      expect(registry.for_type(:on_failed).size).to eq(1)
      expect(child.for_type(:on_failed).size).to eq(2)
    end
  end
end
