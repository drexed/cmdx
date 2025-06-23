# frozen_string_literal: true

module CMDx
  class Batch < Task

    Group = Struct.new(:tasks, :options)

    class << self

      def batch_groups
        @batch_groups ||= []
      end

      def process(*tasks, **options)
        batch_groups << Group.new(
          tasks.flatten.map do |task|
            next task if task <= Task

            raise TypeError, "must be a Task or Batch"
          end,
          options
        )
      end

    end

    def call
      self.class.batch_groups.each do |group|
        next unless __cmdx_eval(group.options)

        batch_halt = group.options[:batch_halt] || task_setting(:batch_halt)

        group.tasks.each do |task|
          task_result = task.call(context)
          next unless Array(batch_halt).include?(task_result.status)

          throw!(task_result)
        end
      end
    end

  end
end
