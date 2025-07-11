# frozen_string_literal: true

module CMDx
  class Context < LazyStruct

    def self.build(context = {})
      return context if context.is_a?(self) && !context.frozen?

      new(context)
    end

  end
end
