# frozen_string_literal: true

RSpec.describe "CMDx exception hierarchy" do
  it "Error inherits from StandardError" do
    expect(CMDx::Error.superclass).to eq(StandardError)
  end

  it "Exception is an alias for Error" do
    expect(CMDx::Exception).to eq(CMDx::Error)
  end

  it "Fault carries result data" do
    result = instance_double("CMDx::Result", task: nil, context: nil, chain: nil)
    fault = CMDx::FailFault.new("bad", result: result)

    expect(fault.message).to eq("bad")
    expect(fault.result).to equal(result)
  end

  it "TimeoutError inherits from Interrupt" do
    expect(CMDx::TimeoutError.superclass).to eq(Interrupt)
  end

  describe "Fault.for?" do
    it "matches faults from specific task classes" do
      task_class = Class.new(CMDx::Task)
      task = task_class.new
      result = CMDx::Result.new(task: task, context: CMDx::Context.new)
      fault = CMDx::FailFault.new("bad", result: result)

      matcher = CMDx::FailFault.for?(task_class)
      expect(matcher === fault).to be(true)
    end
  end
end
