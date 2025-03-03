# frozen_string_literal: true

class SimulationBatch < ApplicationBatch

  after_execution :trace_result

  # Adding this method to work with anonymous classes
  def self.name
    super || "SimulationBatch"
  end

  private

  def trace_result
    (ctx.results ||= []) << "#{self.class.name || 'Unknown'}.#{result.status}"
  end

end
