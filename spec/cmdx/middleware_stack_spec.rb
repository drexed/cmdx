# frozen_string_literal: true

RSpec.describe CMDx::MiddlewareStack do
  let(:session) { CMDx::Session.new(CMDx::Definition.root, {}) }
  let(:task) { CMDx::Task.allocate.tap { |t| t.instance_variable_set(:@context, session.context) } }
  let(:env) { CMDx::MiddlewareEnv.new(session:, task:) }

  describe ".call" do
    it "executes inner block with no middleware" do
      called = false
      described_class.call([], env) { called = true }
      expect(called).to be true
    end

    it "wraps inner block with middleware" do
      order = []
      mw = Module.new
      mw.define_singleton_method(:call) do |_env, **, &blk|
        order << :before
        blk.call
        order << :after
      end

      described_class.call([[mw, {}]], env) { order << :inner }
      expect(order).to eq(%i[before inner after])
    end

    it "raises if middleware does not yield" do
      bad_mw = Module.new
      bad_mw.define_singleton_method(:call) { |_env, **, &_blk| nil }

      expect do
        described_class.call([[bad_mw, {}]], env) { nil }
      end.to raise_error(CMDx::MiddlewareError, /did not yield/)
    end
  end
end
