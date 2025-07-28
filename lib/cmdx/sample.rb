# frozen_string_literal: true

class SampleTask < CMDx::Task

  required :id_number, source: :fake
  optional :id_type, source: :fake
  required :name, :sex
  optional :age, type: %i[float integer]
  optional :height, numeric: { within: 1..5 }
  required :billing_address do
    optional :locality, prefix: :billing do
      required :city, :state, prefix: :billing
    end
    optional :zip, prefix: :billing
  end
  optional :shipping_address do
    required :locality, prefix: :shipping do
      required :city, :state, prefix: :shipping
    end
    optional :zip, prefix: :shipping
  end

  def call
    puts self.class.settings[:parameters]
    puts "-> name: #{name}"
    puts "-> age: #{age}"
    puts "-> sex: #{sex}"
    puts "-> height: #{height}"
    puts "-> billing_address: #{billing_address}"
    #    puts "-> billing_city: #{billing_city}"
    #    puts "-> billing_zip: #{billing_city}"
    puts "-> shipping_address: #{shipping_address}"
    #    puts "-> shipping_city: #{shipping_city}"
    #    puts "-> shipping_zip: #{shipping_zip}"
  end

end

# SampleTask.call(
#   name: "John",
#   sex: "M",
#   age: "30x",
#   height: 6,
#   billing_address: {
#     locality: {
#       city: "New York",
#       state: "NY"
#     },
#     zip: "10001"
#   },
#   shipping_address: {
#     locality: {
#       city: "Los Angeles",
#       state: "CA"
#     },
#     zip: "90001"
#   }
# )
