# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::CoreExt::ModuleExtensions do # rubocop:disable RSpec/SpecFilePathFormat
  describe "#cmdx_attr_delegator" do
    let(:test_class) { Class.new }
    let(:logger_mock) { double("Logger") }

    context "with basic delegation" do
      subject(:instance) { test_class.new(logger_mock) }

      before do
        test_class.class_eval do
          attr_reader :logger

          def initialize(logger)
            @logger = logger
          end

          cmdx_attr_delegator :info, :warn, :error, to: :logger
        end
      end

      it "delegates methods to the target object" do
        expect(logger_mock).to receive(:info).with("test message")
        instance.info("test message")
      end

      it "delegates multiple methods" do
        expect(logger_mock).to receive(:warn).with("warning")
        expect(logger_mock).to receive(:error).with("error")

        instance.warn("warning")
        instance.error("error")
      end

      it "passes arguments and blocks correctly" do
        block = proc { "test block" }
        expect(logger_mock).to receive(:info).with("message", level: :debug, &block)
        instance.info("message", level: :debug, &block)
      end
    end

    context "with method delegation" do
      subject(:instance) { test_class.new(logger_mock) }

      before do
        test_class.class_eval do
          attr_reader :logger

          def initialize(logger)
            @logger = logger
          end

          cmdx_attr_delegator :debug, :fatal, to: :logger
        end
      end

      it "delegates to methods that return objects" do
        expect(logger_mock).to receive(:debug).with("debug message")
        instance.debug("debug message")
      end
    end

    context "with class delegation" do
      subject(:instance) { test_class.new }

      let(:class_logger) { double("ClassLogger") }

      before do
        test_class.class_eval do
          def self.logger
            class_logger
          end

          cmdx_attr_delegator :log, to: :class
        end
      end

      it "delegates to class when :to is :class" do
        expect(test_class).to receive(:log).with("class message")
        instance.log("class message")
      end
    end

    context "with method name modifications" do
      subject(:instance) { test_class.new(double("Task")) }

      before do
        test_class.class_eval do
          attr_reader :task

          def initialize(task)
            @task = task
          end

          cmdx_attr_delegator :perform, to: :task, prefix: "execute_"
          cmdx_attr_delegator :validate, to: :task, suffix: "_data"
          cmdx_attr_delegator :process, to: :task, prefix: "run_", suffix: "_job"
        end
      end

      it "applies prefix to method name" do
        expect(instance.task).to receive(:perform).with("data")
        instance.execute_perform("data")
      end

      it "applies suffix to method name" do
        expect(instance.task).to receive(:validate).with("input")
        instance.validate_data("input")
      end

      it "applies both prefix and suffix" do
        expect(instance.task).to receive(:process).with("payload")
        instance.run_process_job("payload")
      end
    end

    context "with privacy levels" do
      subject(:instance) { test_class.new(double("Service")) }

      before do
        test_class.class_eval do
          attr_reader :service

          def initialize(service)
            @service = service
          end

          cmdx_attr_delegator :public_method, to: :service
          cmdx_attr_delegator :protected_method, to: :service, protected: true
          cmdx_attr_delegator :private_method, to: :service, private: true
        end
      end

      it "creates public methods by default" do
        expect(instance.service).to receive(:public_method)
        instance.public_method
      end

      it "creates protected methods when specified" do
        expect(instance.service).to receive(:protected_method)
        instance.send(:protected_method)
      end

      it "creates private methods when specified" do
        expect(instance.service).to receive(:private_method)
        instance.send(:private_method)
      end

      it "respects method visibility" do
        expect(instance.public_methods).to include(:public_method)
        expect(instance.protected_methods).to include(:protected_method)
        expect(instance.private_methods).to include(:private_method)
      end
    end

    context "with allow_missing option" do
      subject(:instance) { test_class.new(target_mock) }

      let(:target_mock) { double("Target") }

      before do
        test_class.class_eval do
          attr_reader :target

          def initialize(target)
            @target = target
          end

          cmdx_attr_delegator :existing_method, to: :target
          cmdx_attr_delegator :missing_method, to: :target, allow_missing: true
        end
      end

      it "raises NoMethodError when method doesn't exist and allow_missing is false" do
        allow(target_mock).to receive(:respond_to?).with(:existing_method, true).and_return(false)

        expect { instance.existing_method }.to raise_error(NoMethodError, /undefined method `existing_method'/)
      end

      it "allows delegation to non-existent methods when allow_missing is true" do
        allow(target_mock).to receive(:respond_to?).with(:missing_method, true).and_return(false)
        allow(target_mock).to receive(:missing_method).and_return("result")

        expect(instance.missing_method).to eq("result")
      end
    end

    context "with edge cases" do
      subject(:instance) { test_class.new(nil_target) }

      let(:nil_target) { nil }

      before do
        test_class.class_eval do
          attr_reader :target

          def initialize(target)
            @target = target
          end

          cmdx_attr_delegator :test_method, to: :target, allow_missing: true
        end
      end

      it "handles nil target gracefully when allow_missing is true" do
        expect { instance.test_method }.to raise_error(NoMethodError)
      end
    end
  end

  describe "#cmdx_attr_setting" do
    let(:base_class) { Class.new }
    let(:child_class) { Class.new(base_class) }

    context "with default values" do
      before do
        base_class.class_eval do
          cmdx_attr_setting :timeout, default: 30
          cmdx_attr_setting :retries, default: 3
        end
      end

      it "returns default value when not set" do
        expect(base_class.timeout).to eq(30)
        expect(base_class.retries).to eq(3)
      end

      it "caches the value after first access" do
        first_call = base_class.timeout
        second_call = base_class.timeout

        expect(first_call).to be(second_call)
      end

      it "caches values to improve performance" do
        base_class.class_eval do
          cmdx_attr_setting :config, default: { enabled: true }
        end

        config1 = base_class.config
        config2 = base_class.config

        expect(config1).to eq(config2)
        expect(config1).to be(config2) # Same object due to caching
      end

      it "duplicates inherited values to prevent mutation between classes" do
        base_class.class_eval do
          cmdx_attr_setting :shared_config, default: { enabled: true }
        end

        # Access value in base class first to set up inheritance
        base_config = base_class.shared_config
        expect(base_config[:enabled]).to be true

        # Child class should inherit and get a duplicate
        child_config = child_class.shared_config
        expect(child_config[:enabled]).to be true
        expect(child_config).not_to be(base_config)

        # Mutating one shouldn't affect the other
        base_config[:enabled] = false
        expect(child_config[:enabled]).to be true
      end
    end

    context "with proc defaults" do
      before do
        base_class.class_eval do
          cmdx_attr_setting :dynamic_timeout, default: -> { ENV.fetch("TIMEOUT", "60").to_i }
          cmdx_attr_setting :timestamp, default: -> { Time.now }
        end
      end

      it "evaluates proc on each class that accesses it" do
        allow(ENV).to receive(:fetch).with("TIMEOUT", "60").and_return("45")

        expect(base_class.dynamic_timeout).to eq(45)
      end

      it "evaluates procs per class hierarchy" do
        counter = 0
        base_class.class_eval do
          cmdx_attr_setting :counter, default: -> { counter += 1 }
        end

        result1 = base_class.counter
        result2 = child_class.counter

        expect(result1).to eq(1)
        expect(result2).to eq(1) # Child inherits evaluated result from parent
      end
    end

    context "with inheritance" do
      before do
        base_class.class_eval do
          cmdx_attr_setting :base_setting, default: "base_value"
          cmdx_attr_setting :shared_setting, default: "original"
        end

        child_class.class_eval do
          cmdx_attr_setting :child_setting, default: "child_value"
        end
      end

      it "inherits settings from parent class" do
        expect(child_class.base_setting).to eq("base_value")
      end

      it "has its own settings" do
        expect(child_class.child_setting).to eq("child_value")
        expect { base_class.child_setting }.to raise_error(NoMethodError)
      end

      it "can override parent settings" do
        # Set value in parent
        base_class.instance_variable_set(:@cmd_facets, { shared_setting: "modified" })

        # Child inherits the modified value
        expect(child_class.shared_setting).to eq("modified")
      end
    end

    context "with caching behavior" do
      before do
        base_class.class_eval do
          cmdx_attr_setting :cached_value, default: "initial"
        end
      end

      it "caches values in @cmd_facets" do
        expect(base_class.instance_variable_get(:@cmd_facets)).to be_nil

        base_class.cached_value

        facets = base_class.instance_variable_get(:@cmd_facets)
        expect(facets).to be_a(Hash)
        expect(facets[:cached_value]).to eq("initial")
      end

      it "returns cached value on subsequent calls" do
        base_class.cached_value # First call

        # Manually change cached value
        base_class.instance_variable_get(:@cmd_facets)[:cached_value] = "modified"

        expect(base_class.cached_value).to eq("modified")
      end
    end

    context "with edge cases" do
      before do
        base_class.class_eval do
          cmdx_attr_setting :nil_default, default: nil
          cmdx_attr_setting :false_default, default: false
          cmdx_attr_setting :no_default
        end
      end

      it "handles nil default values" do
        expect(base_class.nil_default).to be_nil
      end

      it "handles false default values" do
        expect(base_class.false_default).to be false
      end

      it "handles missing default values" do
        expect(base_class.no_default).to be_nil
      end
    end
  end

  describe "module inclusion" do
    it "includes ModuleExtensions in Module" do
      expect(Module.included_modules).to include(CMDx::CoreExt::ModuleExtensions)
    end

    it "makes methods available on all modules" do
      test_module = Module.new
      expect(test_module).to respond_to(:cmdx_attr_delegator)
      expect(test_module).to respond_to(:cmdx_attr_setting)
    end
  end
end
