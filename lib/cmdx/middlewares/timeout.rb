# frozen_string_literal: true

module CMDx
  module Middlewares
    module Timeout

      extend self

      def call(task, **options)
        # TODO: make a real middleware
        puts "~~~ [BEGIN] Timeout Middleware ~~~"
        result = yield
        puts "~~~ [END] Timeout Middleware ~~~"
        result
      end

    end
  end
end
