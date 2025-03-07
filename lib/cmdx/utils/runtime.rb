# frozen_string_literal: true

module CMDx
  module Utils
    module Runtime

      module_function

      def call(&)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
        yield
        finish = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

        finish - start
      end

    end
  end
end
