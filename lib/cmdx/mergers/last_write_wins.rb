# frozen_string_literal: true

module CMDx
  class Mergers
    # Default merger. Shallow-merges the parallel task's context into the
    # workflow context via `Hash#merge` semantics; on key conflicts, the
    # later-declared task wins.
    #
    # @api private
    module LastWriteWins

      extend self

      # @param ctx [Context] workflow context being folded into
      # @param result [Result] successful parallel task result
      # @return [void]
      def call(ctx, result)
        ctx.merge(result.context)
      end

    end
  end
end
