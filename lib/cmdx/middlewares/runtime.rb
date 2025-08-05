# frozen_string_literal: true

module CMDx
  module Middlewares
    module Runtime

      extend self

      def call(task, **options)
        now = monotonic_time
        result = yield
        task.result.metadata[:runtime] = monotonic_time - now
        result
      end

      private

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
      end

    end
  end
end
