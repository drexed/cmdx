# frozen_string_literal: true

class SimulationTask < ApplicationTask

  after_execution :trace_result

  # Adding this method to work with anonymous classes
  def self.name
    super || "SimulationTask"
  end

  def call
    case context.simulate
    when :success, NilClass
      # Do nothing...
    when :skipped
      skip!
    when :failed
      fail!
    when /grand_child_/
      simulation = context.simulate.to_s.sub("grand_", "").to_sym
      result = SimulationTask.call(context.merge!(simulate: simulation))
      throw!(result)
    when /child_/
      simulation = context.simulate.to_s.sub("child_", "").to_sym
      result = SimulationTask.call(context.merge!(simulate: simulation))
      throw!(result)
    else
      raise "undefined simulation type: #{context.simulate.inspect}"
    end
  end

  private

  def trace_result
    (ctx.results ||= []) << "#{self.class.name || 'Unknown'}.#{result.status}"
  end

end
