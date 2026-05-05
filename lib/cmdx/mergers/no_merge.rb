# frozen_string_literal: true

module CMDx
  class Mergers
    # No-op merger. Leaves the workflow context untouched; per-task results
    # remain inspectable via `result.chain`.
    #
    # @api private
    module NoMerge

      extend self

      # @param _ctx [Context] ignored
      # @param _result [Result] ignored
      # @return [void]
      def call(_ctx, _result); end

    end
  end
end
