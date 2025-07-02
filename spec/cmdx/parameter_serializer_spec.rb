# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParameterSerializer do
  let(:task_class) { create_simple_task }

  describe ".call" do
    context "when serializing basic parameter information" do
      it "returns hash with all parameter attributes" do
        parameter = CMDx::Parameter.new(:user_id, klass: task_class, type: :integer, required: true)

        result = described_class.call(parameter)

        expect(result).to eq({
                               source: :context,
                               name: :user_id,
                               type: :integer,
                               required: true,
                               options: {},
                               children: []
                             })
      end

      it "serializes optional parameters correctly" do
        parameter = CMDx::Parameter.new(:priority, klass: task_class, type: :string, required: false)

        result = described_class.call(parameter)

        expect(result).to eq({
                               source: :context,
                               name: :priority,
                               type: :string,
                               required: false,
                               options: {},
                               children: []
                             })
      end

      it "handles virtual type parameters" do
        parameter = CMDx::Parameter.new(:metadata, klass: task_class)

        result = described_class.call(parameter)

        expect(result).to eq({
                               source: :context,
                               name: :metadata,
                               type: :virtual,
                               required: false,
                               options: {},
                               children: []
                             })
      end
    end

    context "when serializing parameters with custom options" do
      it "includes validation options in serialized hash" do
        parameter = CMDx::Parameter.new(:email, klass: task_class, type: :string,
                                                format: { with: /@/ }, presence: true)

        result = described_class.call(parameter)

        expect(result).to eq({
                               source: :context,
                               name: :email,
                               type: :string,
                               required: false,
                               options: { format: { with: /@/ }, presence: true },
                               children: []
                             })
      end

      it "serializes numeric validation options" do
        parameter = CMDx::Parameter.new(:age, klass: task_class, type: :integer,
                                              numeric: { min: 18, max: 120 })

        result = described_class.call(parameter)

        expect(result).to eq({
                               source: :context,
                               name: :age,
                               type: :integer,
                               required: false,
                               options: { numeric: { min: 18, max: 120 } },
                               children: []
                             })
      end

      it "handles complex nested validation options" do
        parameter = CMDx::Parameter.new(:config, klass: task_class, type: :hash,
                                                 presence: true,
                                                 custom: { validator: proc { true } })

        result = described_class.call(parameter)

        expect(result[:source]).to eq(:context)
        expect(result[:name]).to eq(:config)
        expect(result[:type]).to eq(:hash)
        expect(result[:required]).to be(false)
        expect(result[:options][:presence]).to be(true)
        expect(result[:options][:custom]).to include(:validator)
        expect(result[:children]).to eq([])
      end
    end

    context "when serializing parameters with custom sources" do
      it "uses custom source in serialized hash" do
        parameter = CMDx::Parameter.new(:name, klass: task_class, source: :user, type: :string)

        result = described_class.call(parameter)

        expect(result).to eq({
                               source: :user,
                               name: :name,
                               type: :string,
                               required: false,
                               options: { source: :user },
                               children: []
                             })
      end

      it "handles proc-based sources" do
        source_proc = -> { current_user }
        parameter = CMDx::Parameter.new(:profile, klass: task_class, source: source_proc)

        result = described_class.call(parameter)

        expect(result[:source]).to eq(source_proc)
        expect(result[:name]).to eq(:profile)
        expect(result[:type]).to eq(:virtual)
        expect(result[:required]).to be(false)
        expect(result[:options]).to eq({ source: source_proc })
        expect(result[:children]).to eq([])
      end
    end

    context "when serializing parameters with custom method names" do
      it "uses method name instead of parameter name" do
        parameter = CMDx::Parameter.new(:id, klass: task_class, as: :user_id, type: :integer)

        result = described_class.call(parameter)

        expect(result).to eq({
                               source: :context,
                               name: :user_id,
                               type: :integer,
                               required: false,
                               options: { as: :user_id },
                               children: []
                             })
      end

      it "applies prefix to method name" do
        parameter = CMDx::Parameter.new(:name, klass: task_class, prefix: "get_", type: :string)

        result = described_class.call(parameter)

        expect(result).to eq({
                               source: :context,
                               name: :get_name,
                               type: :string,
                               required: false,
                               options: { prefix: "get_" },
                               children: []
                             })
      end

      it "applies suffix to method name" do
        parameter = CMDx::Parameter.new(:value, klass: task_class, suffix: "_data", type: :string)

        result = described_class.call(parameter)

        expect(result).to eq({
                               source: :context,
                               name: :value_data,
                               type: :string,
                               required: false,
                               options: { suffix: "_data" },
                               children: []
                             })
      end
    end

    context "when serializing parameters with different types" do
      it "handles string type parameters" do
        parameter = CMDx::Parameter.new(:title, klass: task_class, type: :string)

        result = described_class.call(parameter)

        expect(result[:type]).to eq(:string)
      end

      it "handles integer type parameters" do
        parameter = CMDx::Parameter.new(:count, klass: task_class, type: :integer)

        result = described_class.call(parameter)

        expect(result[:type]).to eq(:integer)
      end

      it "handles boolean type parameters" do
        parameter = CMDx::Parameter.new(:enabled, klass: task_class, type: :boolean)

        result = described_class.call(parameter)

        expect(result[:type]).to eq(:boolean)
      end

      it "handles array type parameters" do
        parameter = CMDx::Parameter.new(:tags, klass: task_class, type: :array)

        result = described_class.call(parameter)

        expect(result[:type]).to eq(:array)
      end

      it "handles hash type parameters" do
        parameter = CMDx::Parameter.new(:metadata, klass: task_class, type: :hash)

        result = described_class.call(parameter)

        expect(result[:type]).to eq(:hash)
      end

      it "handles multiple types" do
        parameter = CMDx::Parameter.new(:value, klass: task_class, type: %i[string integer])

        result = described_class.call(parameter)

        expect(result[:type]).to eq(%i[string integer])
      end
    end

    context "when serializing nested parameters" do
      it "recursively serializes child parameters" do
        parameter = CMDx::Parameter.new(:address, klass: task_class) do
          required :street, type: :string
          required :city, type: :string
          optional :apartment, type: :string
        end

        result = described_class.call(parameter)

        expect(result[:source]).to eq(:context)
        expect(result[:name]).to eq(:address)
        expect(result[:type]).to eq(:virtual)
        expect(result[:required]).to be(false)
        expect(result[:options]).to eq({})
        expect(result[:children].size).to eq(3)

        street_child = result[:children].find { |c| c[:name] == :street }
        expect(street_child).to eq({
                                     source: :address,
                                     name: :street,
                                     type: :string,
                                     required: true,
                                     options: {},
                                     children: []
                                   })

        city_child = result[:children].find { |c| c[:name] == :city }
        expect(city_child).to eq({
                                   source: :address,
                                   name: :city,
                                   type: :string,
                                   required: true,
                                   options: {},
                                   children: []
                                 })

        apartment_child = result[:children].find { |c| c[:name] == :apartment }
        expect(apartment_child).to eq({
                                        source: :address,
                                        name: :apartment,
                                        type: :string,
                                        required: false,
                                        options: {},
                                        children: []
                                      })
      end

      it "handles deeply nested parameter structures" do
        parameter = CMDx::Parameter.new(:user, klass: task_class) do
          required :profile do
            required :name, type: :string
            optional :bio, type: :string
          end
          optional :settings do
            required :theme, type: :string, default: "light"
          end
        end

        result = described_class.call(parameter)

        expect(result[:children].size).to eq(2)

        profile_child = result[:children].find { |c| c[:name] == :profile }
        expect(profile_child[:required]).to be(true)
        expect(profile_child[:children].size).to eq(2)

        name_grandchild = profile_child[:children].find { |c| c[:name] == :name }
        expect(name_grandchild).to eq({
                                        source: :profile,
                                        name: :name,
                                        type: :string,
                                        required: true,
                                        options: {},
                                        children: []
                                      })

        settings_child = result[:children].find { |c| c[:name] == :settings }
        expect(settings_child[:required]).to be(false)
        expect(settings_child[:children].size).to eq(1)

        theme_grandchild = settings_child[:children].first
        expect(theme_grandchild).to eq({
                                         source: :settings,
                                         name: :theme,
                                         type: :string,
                                         required: true,
                                         options: { default: "light" },
                                         children: []
                                       })
      end

      it "handles empty children arrays correctly" do
        parameter = CMDx::Parameter.new(:simple, klass: task_class, type: :string)

        result = described_class.call(parameter)

        expect(result[:children]).to eq([])
      end
    end

    context "when serializing parameters with mixed configurations" do
      it "combines all parameter features correctly" do
        parameter = CMDx::Parameter.new(:order, klass: task_class, source: :request,
                                                type: :hash, required: true,
                                                presence: true, as: :order_data) do
          required :total, type: :float, numeric: { min: 0.01 }
          optional :discount, type: :float, default: 0.0
        end

        result = described_class.call(parameter)

        expect(result).to eq({
                               source: :request,
                               name: :order_data,
                               type: :hash,
                               required: true,
                               options: { as: :order_data, presence: true, source: :request },
                               children: [
                                 {
                                   source: :order_data,
                                   name: :total,
                                   type: :float,
                                   required: true,
                                   options: { numeric: { min: 0.01 } },
                                   children: []
                                 },
                                 {
                                   source: :order_data,
                                   name: :discount,
                                   type: :float,
                                   required: false,
                                   options: { default: 0.0 },
                                   children: []
                                 }
                               ]
                             })
      end

      it "handles parameters with validation and naming options" do
        parameter = CMDx::Parameter.new(:email_address, klass: task_class,
                                                        as: :user_email, type: :string,
                                                        format: { with: /@/ }, presence: true,
                                                        required: true)

        result = described_class.call(parameter)

        expect(result).to eq({
                               source: :context,
                               name: :user_email,
                               type: :string,
                               required: true,
                               options: { as: :user_email, format: { with: /@/ }, presence: true },
                               children: []
                             })
      end
    end

    context "when delegating to parameter methods" do
      it "calls method_source on the parameter" do
        parameter = CMDx::Parameter.new(:test, klass: task_class)

        expect(parameter).to receive(:method_source).and_return(:custom_source)
        allow(parameter).to receive_messages(method_name: :test, type: :virtual, required?: false, options: {}, children: [])

        result = described_class.call(parameter)

        expect(result[:source]).to eq(:custom_source)
      end

      it "calls method_name on the parameter" do
        parameter = CMDx::Parameter.new(:test, klass: task_class)

        expect(parameter).to receive(:method_name).and_return(:custom_name)
        allow(parameter).to receive_messages(method_source: :context, type: :virtual, required?: false, options: {}, children: [])

        result = described_class.call(parameter)

        expect(result[:name]).to eq(:custom_name)
      end

      it "calls to_h on child parameters" do
        child_parameter = instance_double(CMDx::Parameter)
        allow(child_parameter).to receive(:to_h).and_return({ name: :child })

        parameter = CMDx::Parameter.new(:parent, klass: task_class)
        allow(parameter).to receive_messages(method_source: :context, method_name: :parent, type: :virtual, required?: false, options: {}, children: [child_parameter])

        result = described_class.call(parameter)

        expect(result[:children]).to eq([{ name: :child }])
      end
    end
  end
end
