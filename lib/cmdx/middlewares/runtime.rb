# frozen_string_literal: true

module CMDx
  module Middlewares
    module Runtime

      extend self

      def call(task, callable, **options)
        # TODO: make a real middleware
        puts "~~~ [BEGIN] Runtime Middleware ~~~"
        result = callable.call(task)
        puts "~~~ [END] Runtime Middleware ~~~"
        result
      end

    end
  end
end
