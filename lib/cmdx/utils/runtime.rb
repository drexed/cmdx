# frozen_string_literal: true

module CMDx
  module Utils
    module Runtime

      module_function

      def call(&)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield
        finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        (finish - start).round(3)
      end

    end
  end
end
