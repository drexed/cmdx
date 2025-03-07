# frozen_string_literal: true

module LogFormatterHelpers

  module_function

  def simulation_output(formatter, simulate)
    local_io = StringIO.new

    Class.new(SimulationTask) do
      task_settings!(logger: Logger.new(local_io, formatter: formatter.new))
    end.call(simulate:)

    local_io
  end

end
