# frozen_string_literal: true

module CMDx
  module Utils
    module Condition

      EVALUATOR = proc do |target, option|
        case option
        when Symbol, String then target.send(option)
        when Proc then option.call(target)
        else option
        end
      end.freeze

      module_function

      def call(target, options = {})
        case options
        in { if: xif, unless: xunless }
          EVALUATOR.call(target, xif) && !EVALUATOR.call(target, xunless)
        in { if: xif }
          EVALUATOR.call(target, xif)
        in { unless: xunless }
          !EVALUATOR.call(target, xunless)
        else
          options.fetch(:default, true)
        end
      end

    end
  end
end
