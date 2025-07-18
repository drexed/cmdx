# frozen_string_literal: true

module CMDx
  # Provides formatted inspection and display functionality for execution chains.
  #
  # This module formats chain execution information into a human-readable string
  # representation, including the chain ID, individual task results, and summary
  # information about the chain's final state.
  module ChainInspector

    FOOTER_KEYS = %i[
      state status outcome runtime
    ].freeze

    module_function

    # Formats a chain into a human-readable inspection string.
    #
    # Creates a formatted display showing the chain ID, individual task results,
    # and summary footer with execution state information. The output includes
    # visual separators and structured formatting for easy reading.
    #
    # @param chain [CMDx::Chain] the chain object to inspect
    #
    # @return [String] formatted multi-line string representation of the chain
    #
    # @raise [NoMethodError] if chain doesn't respond to required methods (id, results, state, status, outcome, runtime)
    #
    # @example Inspect a simple chain
    #   chain = CMDx::Chain.new(id: "abc123")
    #   result = CMDx::Result.new(task)
    #   chain.results << result
    #   puts CMDx::ChainInspector.call(chain)
    #   # Output:
    #   # chain: abc123
    #   # ===================
    #   #
    #   # {:state=>"complete", :status=>"success", ...}
    #   #
    #   # ===================
    #   # state: complete | status: success | outcome: success | runtime: 0.001
    def call(chain)
      header = "\nchain: #{chain.id}"
      footer = FOOTER_KEYS.map { |key| "#{key}: #{chain.send(key)}" }.join(" | ")
      spacer = "=" * [header.size, footer.size].max

      chain
        .results
        .map { |r| r.to_h.except(:chain_id).pretty_inspect }
        .unshift(header, "#{spacer}\n")
        .push(spacer, "#{footer}\n\n")
        .join("\n")
    end

  end
end
