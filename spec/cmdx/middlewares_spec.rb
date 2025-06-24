# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middlewares do
  include_context "with middleware chain behavior"

  let(:middleware_class) do
    Class.new(CMDx::Middleware) do
      def initialize(name) # rubocop:disable Lint/MissingSuper
        @name = name
      end

      def call(task, callable)
        task.context.middleware_calls ||= []
        task.context.middleware_calls << "#{@name}_before"

        result = callable.call(task)

        task.context.middleware_calls << "#{@name}_after"
        result
      end
    end
  end

  let(:task_class) do
    Class.new(CMDx::Task) do
      def call
        context.middleware_calls ||= []
        context.middleware_calls << "task_executed"
      end
    end
  end

  let(:registry) { described_class.new }

  describe "#initialize" do
    context "with no arguments" do
      it_behaves_like "middleware registry operations"
    end

    context "with initial registry" do
      let(:initial_registry) { [[middleware_class, ["test"], nil]] }
      let(:registry) { described_class.new(initial_registry) }

      it "accepts and uses initial middleware" do
        expect(registry.size).to eq 1
        expect(registry.empty?).to be false
      end

      it "creates independent copy of initial registry" do
        original_registry = [[middleware_class, ["original"], nil]]
        registry = described_class.new(original_registry)

        original_registry << [middleware_class, ["added"], nil]

        expect(registry.size).to eq 1
      end
    end
  end

  describe "#use" do
    it_behaves_like "middleware registry operations"

    context "with different middleware types" do
      it "adds middleware class with arguments" do
        registry.use(middleware_class, "test_arg")

        expect(registry.size).to eq 1
        expect(registry.empty?).to be false
      end

      it "adds middleware instance" do
        instance = middleware_class.new("test_instance")
        registry.use(instance)

        expect(registry.size).to eq 1
      end

      it "adds proc middleware" do
        proc_middleware = proc { |task, callable| callable.call(task) }
        registry.use(proc_middleware)

        expect(registry.size).to eq 1
      end

      it "adds middleware with block" do
        registry.use(middleware_class, "test") do |config|
          config.enable_feature = true
        end

        expect(registry.size).to eq 1
      end
    end
  end

  describe "#call" do
    context "with empty registry" do
      it "executes block directly" do
        result = registry.call(task) do |t|
          t.call
          t.result
        end

        expect(task.context.middleware_calls).to eq(%w[task_executed])
        expect(result).to be_a(CMDx::Result)
      end
    end

    context "with single middleware" do
      subject do
        registry.call(task) do |t|
          t.call
          t.result
        end
      end

      before { registry.use(middleware_class, "first") }

      it_behaves_like "middleware execution", %w[first_before task_executed first_after]
    end

    context "with multiple middleware" do
      subject do
        registry.call(task) do |t|
          t.call
          t.result
        end
      end

      before do
        registry.use(middleware_class, "first")
        registry.use(middleware_class, "second")
        registry.use(middleware_class, "third")
      end

      it_behaves_like "middleware execution", %w[
        first_before
        second_before
        third_before
        task_executed
        third_after
        second_after
        first_after
      ]
    end

    context "with short-circuiting middleware" do
      subject do
        registry.call(task) do |t|
          t.call
          t.result
        end
      end

      include_context "short-circuiting middleware"

      before do
        registry.use(middleware_class, "first")
        registry.use(short_circuit_middleware)
        registry.use(middleware_class, "third")
      end

      it_behaves_like "short-circuiting middleware"

      it "executes remaining middleware in reverse order" do
        result = subject

        expect(task.context.middleware_calls).to eq(
          %w[
            first_before
            short_circuit
            first_after
          ]
        )
        expect(result.skipped?).to be true
      end
    end

    context "with proc middleware" do
      subject do
        registry.call(task) do |t|
          t.call
          t.result
        end
      end

      include_context "proc middleware"

      before { registry.use(proc_middleware) }

      it_behaves_like "proc middleware"
    end

    context "with mixed middleware types" do
      let(:instance_middleware) { middleware_class.new("instance") }

      before do
        registry.use(middleware_class, "class")
        registry.use(instance_middleware)
        registry.use(proc { |task, callable|
          task.context.middleware_calls ||= []
          task.context.middleware_calls << "proc_middleware"
          callable.call(task)
        })
      end

      it "executes all middleware types correctly" do
        result = registry.call(task) do |t|
          t.call
          t.result
        end

        expect(task.context.middleware_calls).to include(
          "class_before", "class_after",
          "instance_before", "instance_after",
          "proc_middleware",
          "task_executed"
        )
        expect(result).to be_a(CMDx::Result)
      end
    end
  end

  describe "error handling" do
    subject do
      registry.call(task) do |t|
        t.call
        t.result
      end
    end

    include_context "error propagation in middleware"

    before { registry.use(error_middleware) }

    it_behaves_like "error propagation in middleware"
  end

  describe "advanced scenarios" do
    context "with middleware that modifies the task" do
      let(:task_modifier_middleware) do
        Class.new(CMDx::Middleware) do
          def call(task, callable)
            task.context.middleware_calls ||= []
            task.context.middleware_calls << "modifier_before"
            task.context.modified_by_middleware = "modified_value"

            result = callable.call(task)

            task.context.middleware_calls << "modifier_after"
            result
          end
        end
      end

      before { registry.use(task_modifier_middleware) }

      it "allows middleware to modify task state" do
        result = registry.call(task) do |t|
          t.call
          t.result
        end

        expect(task.context.modified_by_middleware).to eq("modified_value")
        expect(task.context.middleware_calls).to include("modifier_before", "modifier_after")
        expect(result).to be_a(CMDx::Result)
      end
    end

    context "with conditional middleware execution" do
      let(:conditional_middleware) do
        Class.new(CMDx::Middleware) do
          def call(task, callable)
            task.context.middleware_calls ||= []

            task.context.middleware_calls << if task.context.should_execute_middleware
                                               "conditional_executed"
                                             else
                                               "conditional_skipped"
                                             end

            callable.call(task)
          end
        end
      end

      before { registry.use(conditional_middleware) }

      it "supports conditional execution within middleware" do
        task.context.should_execute_middleware = true

        result = registry.call(task) do |t|
          t.call
          t.result
        end

        expect(task.context.middleware_calls).to include("conditional_executed")
        expect(task.context.middleware_calls).not_to include("conditional_skipped")
        expect(result).to be_a(CMDx::Result)
      end
    end

    context "with middleware that catches and handles task exceptions" do
      let(:exception_handling_middleware) do
        Class.new(CMDx::Middleware) do
          def call(task, callable)
            task.context.middleware_calls ||= []
            task.context.middleware_calls << "exception_handler_before"

            begin
              result = callable.call(task)
            rescue CMDx::Failed => e
              task.context.middleware_calls << "exception_caught"
              task.context.caught_exception = e.message
              result = task.result
            end

            task.context.middleware_calls << "exception_handler_after"
            result
          end
        end
      end

      let(:failing_task_class) do
        Class.new(CMDx::Task) do
          def call
            context.middleware_calls ||= []
            context.middleware_calls << "task_before_failure"
            fail!(reason: "Intentional failure")
          end
        end
      end

      before { registry.use(exception_handling_middleware) }

      it "allows middleware to catch and handle task exceptions" do
        failing_task = failing_task_class.send(:new, {})

        result = registry.call(failing_task) do |t|
          t.call
          t.result
        end

        expect(failing_task.context.middleware_calls).to include(
          "exception_handler_before",
          "task_before_failure",
          "exception_caught",
          "exception_handler_after"
        )
        expect(failing_task.context.caught_exception).to eq("Intentional failure")
        expect(result.failed?).to be true
      end
    end
  end
end
