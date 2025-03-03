# frozen_string_literal: true

module CMDx
  module TaskHook

    module_function

    def call(task, hook)
      Array(task.class.cmd_hooks[hook]).each do |callables, options|
        next unless task.__cmdx_eval(options)

        hooks = Array(callables)
        hooks.each { |h| task.__cmdx_try(h) }
      end
    end

  end
end
