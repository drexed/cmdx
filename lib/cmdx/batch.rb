# frozen_string_literal: true

module CMDx

  BatchGroup = Struct.new(:tasks, :options)

  class Batch < Task

    class << self

      def batch_groups
        @batch_groups ||= []
      end

      def process(*tasks, **options)
        batch_groups << BatchGroup.new(
          tasks.flatten.map do |task|
            next task if task <= Task

            raise ArgumentError, "must be a Batch or Task"
          end,
          options
        )
      end

    end

    def call
      self.class.batch_groups.each do |batch_group|
        next unless __cmdx_eval(batch_group.options)

        batch_halt = batch_group.options[:batch_halt] || task_setting(:batch_halt)

        batch_group.tasks.each do |task|
          task_result = task.call(context)
          next unless Array(batch_halt).include?(task_result.status)

          throw!(task_result)
        end
      end
    end

  end

end
