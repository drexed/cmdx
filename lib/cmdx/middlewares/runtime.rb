# frozen_string_literal: true

module CMDx
  module Middlewares
    module Runtime

      extend self

      def call(task, callable)
        puts "~~~ Runtime Middleware ~~~"
        callable.call(task)
      end

    end
  end
end
