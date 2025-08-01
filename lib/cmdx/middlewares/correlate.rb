# frozen_string_literal: true

module CMDx
  module Middlewares
    module Correlate

      extend self

      def call(task, callable)
        # TODO: make a real middleware
        puts "~~~ [BEGIN] Correlate Middleware ~~~"
        result = callable.call(task)
        puts "~~~ [END] Correlate Middleware ~~~"
        result
      end

    end
  end
end
