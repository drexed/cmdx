# frozen_string_literal: true

module CMDx
  module RunInspector

    ORDERED_KEYS = %i[
      state status outcome runtime
    ].freeze

    module_function

    def call(run)
      header = "Run: #{run.id}"
      footer = ORDERED_KEYS.map { |key| "#{key}=#{run.send(key)}" }.join(" ")
      spacer = "=" * [header.size, footer.size].max

      run.results.map(&:to_s).unshift(header, spacer).push(spacer, footer).join("\n")
    end

  end
end
