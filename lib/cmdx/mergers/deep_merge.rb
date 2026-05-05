# frozen_string_literal: true

module CMDx
  class Mergers
    # Recursively merges `Hash` values from the parallel task's context into
    # the workflow context. Scalar-vs-hash collisions still follow
    # last-write-wins.
    #
    # @api private
    module DeepMerge

      extend self

      # @param ctx [Context] workflow context being folded into
      # @param result [Result] successful parallel task result
      # @return [void]
      def call(ctx, result)
        ctx.deep_merge(result.context)
      end

    end
  end
end
