# frozen_string_literal: true

class SimulationTask < ApplicationTask

  after_execution :trace_result

  # Adding this method to work with anonymous classes
  def self.name
    super || "SimulationTask"
  end

  def call
    case context.simulate
    when :success, NilClass # Do nothing...
    when :skipped then skip!
    when :failed then fail!
    when /grand_child_/ then simulate_task_call("grand_")
    when /child_/ then simulate_task_call("child_")
    else raise "undefined simulation type: #{context.simulate.inspect}"
    end
  end

  private

  def trace_result
    (ctx.results ||= []) << "#{self.class.name || 'Unknown'}.#{result.status}"
  end

  def simulate_task_call(depth_prefix)
    call_type  = context.simulate.to_s.end_with?("!") ? :call! : :call
    simulation = context.simulate.to_s.sub(depth_prefix, "").delete("!").to_sym
    result = SimulationTask.send(call_type, context.merge!(simulate: simulation))
    throw!(result)
  end

end
