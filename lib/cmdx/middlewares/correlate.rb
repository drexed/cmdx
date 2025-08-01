# frozen_string_literal: true

module CMDx
  module Middlewares
    module Correlate

      extend self

      THREAD_KEY = :cmdx_correlate

      def id
        Thread.current[THREAD_KEY]
      end

      def id=(id)
        Thread.current[THREAD_KEY] = id
      end

      def clear
        Thread.current[THREAD_KEY] = nil
      end

      def use(new_id)
        old_id  = id
        self.id = new_id
        yield
      ensure
        self.id = old_id
      end

      def call(task, **options)
        # TODO: make a real middleware
        puts "~~~ [BEGIN] Correlate Middleware #{options} ~~~"
        result = yield
        puts "~~~ [END] Correlate Middleware ~~~"
        result
      end

    end
  end
end
