# frozen_string_literal: true

module CMDx
  class Run

    __cmdx_attr_delegator :index, to: :results
    __cmdx_attr_delegator :state, :status, :outcome, :runtime, to: :first_result

    attr_reader :id, :results

    def initialize(attributes = {})
      @id      = attributes[:id] || SecureRandom.uuid
      @results = Array(attributes[:results])
    end

    def to_h
      RunSerializer.call(self)
    end

    def to_s
      RunInspector.call(self)
    end

    private

    def first_result
      return @first_result if defined?(@first_result)

      @first_result = @results.first
    end

  end
end
