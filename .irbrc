# frozen_string_literal: true

require "pp"

require_relative "lib/cmdx"

# TODO: remove
class DeepTask < CMDx::Task

  register :middleware, CMDx::Middlewares::Correlate

  def task
    # fail!("test")
    raise(StandardError, "womp womp")
  end

end

class OtherTask < CMDx::Task

  register :middleware, CMDx::Middlewares::Correlate

  def task
    throw!(DeepTask.execute!)
    # raise(StandardError, "test")
  end

end

class SampleTask < CMDx::Task

  register :middleware, CMDx::Middlewares::Correlate, id: "123"
  register :middleware, CMDx::Middlewares::Runtime

  required :id_number, source: :fake
  optional :id_type, source: :fake
  required :name, :sex
  optional :age, type: %i[float integer]
  optional :height, numeric: { within: 1..5 }
  required :weight, prefix: :empirical_, suffix: :_lbs
  required :billing_address do
    optional :locality, prefix: :billing_ do
      required :city, :state, prefix: :billing_
    end
    optional :zip, type: :integer, numeric: { within: 10_000..99_999 }, prefix: :billing_
  end
  optional :shipping_address do
    required :locality, prefix: true do
      required :city, :state, prefix: true
    end
    optional :zip, prefix: true
  end

  before_validation { puts "before_validation" }

  def task
    puts "task"
    throw!(OtherTask.execute!)
    # puts self.class.settings[:parameters]
    # puts "-> name: #{name}"
    # puts "-> age: #{age}"
    # puts "-> sex: #{sex}"
    # puts "-> height: #{height}"
    # puts "-> weight: #{empirical_weight_lbs}"
    # puts "-> billing_address: #{billing_address}"
    # puts "-> billing_locality: #{billing_locality}"
    # puts "-> billing_zip: #{billing_zip}"
    # puts "-> billing_city: #{billing_city}"
    # puts "-> billing_zip: #{billing_zip}"
    # puts "-> shipping_address: #{shipping_address}"
    # puts "-> shipping_address_locality_city: #{shipping_address_locality_city}"
    # puts "-> shipping_address_zip: #{shipping_address_zip}"
  end

end

class SampleWorkflow < CMDx::Task

  include CMDx::Workflow

  tasks SampleTask, SampleTask
  tasks SampleTask

end

def task
  SampleTask.execute(
    name: "John",
    sex: "M",
    age: "30x",
    height: 6,
    weight: 150,
    billing_address: {
      locality: {
        city: "New York",
        state: "NY"
      },
      zip: "10001"
    },
    shipping_address: {
      locality: {
        city: "Los Angeles",
        state: "CA"
      },
      zip: "90001"
    }
  )
end

def workflow
  SampleWorkflow.execute(
    name: "John",
    sex: "M",
    age: "30x",
    height: 6,
    weight: 150
  )
end
