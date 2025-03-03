# frozen_string_literal: true

module CMDx
  class Parameters < Array

    def invalid?
      !valid?
    end

    def valid?
      all?(&:valid?)
    end

    def validate!(task)
      each { |p| recursive_validate!(task, p) }
    end

    def to_h
      ParametersSerializer.call(self)
    end

    def to_s
      ParametersInspector.call(self)
    end

    private

    def recursive_validate!(task, parameter)
      task.send(parameter.method_name)
      parameter.children.each { |cp| recursive_validate!(task, cp) }
    end

  end
end
