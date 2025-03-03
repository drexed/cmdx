# frozen_string_literal: true

module CMDx

  BatchTask = Struct.new(:klass, :options)

  class Batch < Task

    class << self

      def batch_tasks
        @batch_tasks ||= []
      end

      def process(*klasses, **options)
        klasses.flatten.each do |klass|
          raise ArgumentError, "must be a Batch or Task" unless klass <= Task

          batch_tasks << BatchTask.new(klass, options)
        end
      end

    end

    def call
      self.class.batch_tasks.each do |batch_task|
        next unless __cmdx_eval(batch_task.options)

        task_result = batch_task.klass.call(context)
        batch_halt  = batch_task.options[:batch_halt] || task_setting(:batch_halt)
        next unless Array(batch_halt).include?(task_result.status)

        throw!(task_result)
      end
    end

  end

end
