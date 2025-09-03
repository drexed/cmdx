# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task middlewares", type: :feature do
  context "when using correlate middleware" do
    it "assigns a correlation ID to the result metadata" do
      task = create_successful_task do
        register :middleware, CMDx::Middlewares::Correlate, id: proc { "abc-123" }
      end

      result = task.execute

      expect(result.metadata[:correlation_id]).to eq("abc-123")
    end

    it "resuses the correlation ID from the outer task" do
      inner_task = create_successful_task(name: "InnerTask") do
        register :middleware, CMDx::Middlewares::Correlate, id: proc { "abc-456" }
      end
      outer_task = create_task_class(name: "OuterTask") do
        register :middleware, CMDx::Middlewares::Correlate, id: proc { "abc-123" }
      end
      outer_task.define_method(:work) { context.inner_result = inner_task.execute(context) }

      outer_result = outer_task.execute
      inner_result = outer_result.context.inner_result

      expect(inner_result.metadata[:correlation_id]).to eq("abc-123")
      expect(outer_result.metadata[:correlation_id]).to eq("abc-123")
    end
  end

  context "when using runtime middleware" do
    it "assigns the runtime to the result metadata" do
      task = create_successful_task do
        register :middleware, CMDx::Middlewares::Runtime
      end

      result = task.execute

      expect(result.metadata[:runtime]).to be_a(Integer)
    end
  end

  context "when using timeout middleware" do
    it "raises a failure fault" do
      task = create_task_class do
        register :middleware, CMDx::Middlewares::Timeout, seconds: 0.001
      end
      task.define_method(:work) { sleep(0.002) }

      expect { task.execute }.to raise_error(CMDx::FailFault, "[CMDx::TimeoutError] execution exceeded 0.001 seconds")
    end
  end
end
