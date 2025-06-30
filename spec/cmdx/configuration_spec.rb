# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Configuration do
  subject(:config) { described_class.new }

  describe ".new" do
    it "sets default logger with Line formatter" do
      expect(config.logger).to be_a(Logger)
      expect(config.logger.instance_variable_get(:@formatter)).to be_instance_of(CMDx::LogFormatters::Line)
    end

    it "sets default task_halt to 'failed'" do
      expect(config.task_halt).to eq("failed")
    end

    it "sets default batch_halt to 'failed'" do
      expect(config.batch_halt).to eq("failed")
    end

    it "initializes with default middlewares registry" do
      expect(config.middlewares).to be_a(CMDx::MiddlewareRegistry)
      expect(config.middlewares).to be_empty
    end

    it "initializes with default hooks registry" do
      expect(config.hooks).to be_a(CMDx::HookRegistry)
      expect(config.hooks).to be_empty
    end
  end

  describe "#to_h" do
    it "returns a hash with all configuration attributes" do
      result = config.to_h

      expect(result).to be_a(Hash)
      expect(result.keys).to match_array(%i[logger middlewares hooks task_halt batch_halt])
    end

    it "returns current attribute values" do
      config.task_halt = %i[failed skipped]

      result = config.to_h

      expect(result[:task_halt]).to eq(%i[failed skipped])
      expect(result[:logger]).to be_a(Logger)
    end
  end

  describe "attribute accessors" do
    it "allows reading and writing logger" do
      new_logger = Logger.new(nil)
      config.logger = new_logger
      expect(config.logger).to eq(new_logger)
    end

    it "allows reading and writing task_halt" do
      config.task_halt = %i[failed skipped]
      expect(config.task_halt).to eq(%i[failed skipped])
    end

    it "allows reading and writing batch_halt" do
      config.batch_halt = "skipped"
      expect(config.batch_halt).to eq("skipped")
    end

    it "allows reading and writing middlewares" do
      new_middlewares = CMDx::MiddlewareRegistry.new
      test_middleware = Class.new
      new_middlewares.use(test_middleware)

      config.middlewares = new_middlewares
      expect(config.middlewares).to eq(new_middlewares)
      expect(config.middlewares.size).to eq(1)
    end

    it "allows reading and writing hooks" do
      new_hooks = CMDx::HookRegistry.new
      new_hooks.register(:before_execution, :test_hook)

      config.hooks = new_hooks
      expect(config.hooks).to eq(new_hooks)
      expect(config.hooks[:before_execution]).to eq([[[:test_hook], {}]])
    end
  end

  describe "#middlewares" do
    it "allows adding middlewares to the global registry" do
      test_middleware = Class.new do
        def call(task, next_callable)
          next_callable.call(task)
        end
      end

      config.middlewares.use(test_middleware)

      expect(config.middlewares.size).to eq(1)
      expect(config.middlewares.first).to eq([test_middleware, [], nil])
    end

    it "allows adding middlewares with arguments" do
      test_middleware = Class.new do
        def initialize(timeout)
          @timeout = timeout
        end

        def call(task, next_callable)
          next_callable.call(task)
        end
      end

      config.middlewares.use(test_middleware, 30)

      expect(config.middlewares.size).to eq(1)
      expect(config.middlewares.first).to eq([test_middleware, [30], nil])
    end

    it "allows adding multiple middlewares" do
      middleware1 = Class.new
      middleware2 = Class.new

      config.middlewares.use(middleware1)
      config.middlewares.use(middleware2, "arg")

      expect(config.middlewares.size).to eq(2)
      expect(config.middlewares[0]).to eq([middleware1, [], nil])
      expect(config.middlewares[1]).to eq([middleware2, ["arg"], nil])
    end
  end

  describe "#hooks" do
    it "allows adding hooks to the global registry" do
      config.hooks.register(:before_execution, :test_hook)

      expect(config.hooks.keys).to include(:before_execution)
      expect(config.hooks[:before_execution]).to eq([[[:test_hook], {}]])
    end

    it "allows adding hooks with conditions" do
      config.hooks.register(:on_failure, :alert_admin, if: :production?)

      expect(config.hooks[:on_failure]).to eq([[[:alert_admin], { if: :production? }]])
    end

    it "allows adding multiple hooks for the same event" do
      config.hooks.register(:on_success, :log_success)
      config.hooks.register(:on_success, :track_metrics)

      expect(config.hooks[:on_success].size).to eq(2)
      expect(config.hooks[:on_success][0]).to eq([[:log_success], {}])
      expect(config.hooks[:on_success][1]).to eq([[:track_metrics], {}])
    end

    it "allows adding hook instances" do
      hook_instance = CMDx::Hook.new

      config.hooks.register(:before_validation, hook_instance)

      expect(config.hooks[:before_validation]).to eq([[[hook_instance], {}]])
    end

    it "allows adding proc hooks" do
      proc_hook = proc { |_task, _hook_type| puts "Hook executed" }

      config.hooks.register(:after_execution, proc_hook)

      expect(config.hooks[:after_execution]).to eq([[[proc_hook], {}]])
    end
  end
end
