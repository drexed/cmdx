# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Parameter do
  subject(:result) { simulation_task.call(ctx) }

  let(:ctx) do
    {
      title: "Mr.",
      first_name: "John",
      last_name: "Doe",
      address: {
        city: "Miami",
        "state" => "Fl"
      },
      company: instance_double("Company", name: "Ukea", position: "Cashier")
    }
  end

  describe "#parameters" do
    context "with valid setup" do
      let(:simulation_task) do
        Class.new(SimulationTask) do
          required :first_name, :last_name
          optional :address, type: :hash do
            required :city
            optional :state, default: "USA", desc: "Alpha-2"
          end
        end
      end

      it "builds correct parameter map" do
        expect(simulation_task.cmd_parameters.map(&:to_h)).to eq(
          [
            {
              source: :context,
              name: :first_name,
              type: :virtual,
              required: true,
              options: {},
              children: []
            },
            {
              source: :context,
              name: :last_name,
              type: :virtual,
              required: true,
              options: {},
              children: []
            },
            {
              source: :context,
              name: :address,
              type: :hash,
              required: false,
              options: {},
              children: [
                {
                  source: :address,
                  name: :city,
                  type: :virtual,
                  required: true,
                  options: {},
                  children: []
                },
                {
                  source: :address,
                  name: :state,
                  type: :virtual,
                  required: false,
                  options: { default: "USA", desc: "Alpha-2" },
                  children: []
                }
              ]
            }
          ]
        )
      end
    end

    context "without parameters" do
      let(:simulation_task) do
        Class.new(SimulationTask) do
          required
        end
      end

      it "raises an ArgumentError" do
        expect { simulation_task }.to raise_error(ArgumentError, "no parameters given")
      end
    end

    context "with :as option with multiple parameters" do
      let(:simulation_task) do
        Class.new(SimulationTask) do
          required :first_name, :last_name, as: :name
        end
      end

      it "raises an ArgumentError" do
        expect { simulation_task }.to raise_error(ArgumentError, ":as option only supports one parameter per definition")
      end
    end
  end

  describe "#attributes" do
    context "when context params" do
      let(:simulation_task) do
        Class.new(SimulationTask) do
          required :first_name, :last_name
          optional :title, :middle_name

          def call
            context.full_name = [title, first_name, middle_name, last_name]
          end
        end
      end

      it "successfully delegates" do
        expect(result).to be_success
        expect(result.context.full_name).to eq(["Mr.", "John", nil, "Doe"])
      end
    end

    context "when object params" do
      context "with filled present nested values" do
        let(:ctx) { {} }
        let(:simulation_task) do
          Class.new(SimulationTask) do
            required :first_name, :last_name, source: :user
            optional :title, :middle_name, source: :user
            required :address, source: :user do
              required :city
              optional :state, :country
            end

            def call
              context.full_name = [title, first_name, middle_name, last_name]
              context.locality = [city, state, country]
            end

            private

            def user
              @user ||= begin
                user = Struct.new(:title, :first_name, :last_name, :address)
                user.new(
                  "Mr.",
                  "John",
                  "Doe",
                  {
                    city: "Miami",
                    "state" => "Fl"
                  }
                )
              end
            end
          end
        end

        it "successfully delegates" do
          expect(result).to be_success
          expect(result.context.full_name).to eq(["Mr.", "John", nil, "Doe"])
          expect(result.context.locality).to eq(["Miami", "Fl", nil])
        end
      end

      context "when empty nested values" do
        let(:ctx) { {} }
        let(:simulation_task) do
          Class.new(SimulationTask) do
            required :first_name, :last_name, source: :user
            optional :title, :middle_name, source: :user
            required :address, source: :user do
              required :city
              optional :state, :country
            end

            def call
              context.full_name = [title, first_name, middle_name, last_name]
              context.locality = [city, state, country]
            end

            private

            def user
              @user ||= begin
                user = Struct.new(:title, :first_name, :last_name, :address)
                user.new(nil, nil, nil, nil)
              end
            end
          end
        end

        it "fails validation" do
          expect(result).to be_failed
          expect(result).to have_attributes(
            state: CMDx::Result::INTERRUPTED,
            status: CMDx::Result::FAILED,
            metadata: {
              reason: "city is a required parameter",
              messages: { city: ["is a required parameter"] }
            }
          )
        end
      end

      context "when missing nested values" do
        let(:ctx) { {} }
        let(:simulation_task) do
          Class.new(SimulationTask) do
            optional :address do
              required :city
              optional :state, :country
            end

            def call
              context.locality = [city, state, country]
            end
          end
        end

        it "successfully delegates" do
          expect(result).to be_success
          expect(result.context.locality).to eq([nil, nil, nil])
        end
      end
    end

    context "when block params" do
      context "when delegating object" do
        let(:simulation_task) do
          Class.new(SimulationTask) do
            required :company do
              required :name
              optional :position, :salary
            end

            def call
              context.raw_company = company
              context.job = [name, position, salary]
            end
          end
        end

        it "successfully delegates" do
          expect(result).to be_success
          expect(result.context.raw_company).to eq(ctx[:company])
          expect(result.context.job).to eq(["Ukea", "Cashier", nil])
        end
      end

      context "when delegating hash" do
        let(:simulation_task) do
          Class.new(SimulationTask) do
            required :address do
              required :city
              optional :state, :country
            end

            def call
              context.raw_address = address
              context.locality = [city, state, country]
            end
          end
        end

        it "successfully delegates" do
          expect(result).to be_success
          expect(result.context.raw_address).to eq(ctx[:address])
          expect(result.context.locality).to eq(["Miami", "Fl", nil])
        end
      end
    end

    context "with default option" do
      let(:ctx) do
        {
          title: "Mr.",
          first_name: "John",
          middle_name: nil,
          last_name: "Doe",
          address: {
            city: "Miami",
            "state" => "Fl"
          },
          company: instance_double("Company", name: "Ukea", position: "Cashier")
        }
      end
      let(:simulation_task) do
        Class.new(SimulationTask) do
          required :first_name, :middle_name, :last_name, default: "idk1"
          optional :title, :maiden_name, default: proc { "idk2" }

          def call
            context.full_name = [title, first_name, middle_name, last_name, maiden_name]
          end
        end
      end

      it "successfully delegates" do
        expect(result).to be_success
        expect(result.context.full_name).to eq(["Mr.", "John", "idk1", "Doe", "idk2"])
      end
    end

    context "with as option" do
      let(:simulation_task) do
        Class.new(SimulationTask) do
          required :last_name, as: :surname

          def call
            context.raw_last_name = begin
              last_name
            rescue StandardError
              "undefined"
            end

            context.name = [surname]
          end
        end
      end

      it "successfully delegates" do
        expect(result).to be_success
        expect(result.context.raw_last_name).to eq("undefined")
        expect(result.context.name).to eq(["Doe"])
      end
    end

    context "with prefix option" do
      context "with true" do
        let(:simulation_task) do
          Class.new(SimulationTask) do
            required :last_name, prefix: true

            def call
              context.raw_last_name = begin
                last_name
              rescue StandardError
                "undefined"
              end

              context.name = [context_last_name]
            end
          end
        end

        it "successfully delegates" do
          expect(result).to be_success
          expect(result.context.raw_last_name).to eq("undefined")
          expect(result.context.name).to eq(["Doe"])
        end
      end

      context "with value" do
        let(:simulation_task) do
          Class.new(SimulationTask) do
            required :last_name, prefix: :given_

            def call
              context.raw_last_name = begin
                last_name
              rescue StandardError
                "undefined"
              end

              context.name = [given_last_name]
            end
          end
        end

        it "successfully delegates" do
          expect(result).to be_success
          expect(result.context.raw_last_name).to eq("undefined")
          expect(result.context.name).to eq(["Doe"])
        end
      end
    end

    context "with suffix option" do
      context "with true" do
        let(:simulation_task) do
          Class.new(SimulationTask) do
            required :last_name, suffix: true

            def call
              context.raw_last_name = begin
                last_name
              rescue StandardError
                "undefined"
              end

              context.name = [last_name_context]
            end
          end
        end

        it "successfully delegates" do
          expect(result).to be_success
          expect(result.context.raw_last_name).to eq("undefined")
          expect(result.context.name).to eq(["Doe"])
        end
      end

      context "with value" do
        let(:simulation_task) do
          Class.new(SimulationTask) do
            required :last_name, suffix: :_given

            def call
              context.raw_last_name = begin
                last_name
              rescue StandardError
                "undefined"
              end

              context.name = [last_name_given]
            end
          end
        end

        it "successfully delegates" do
          expect(result).to be_success
          expect(result.context.raw_last_name).to eq("undefined")
          expect(result.context.name).to eq(["Doe"])
        end
      end
    end
  end

  describe "#initialize" do
    context "when source method doesn't exist" do
      let(:simulation_task) do
        Class.new(SimulationTask) do
          required :first_name, source: :fake
          optional :title, source: :fake

          def call
            context.full_name = [title, first_name]
          end
        end
      end

      it "fails validation" do
        expect(result).to be_failed
        expect(result).to have_attributes(
          state: CMDx::Result::INTERRUPTED,
          status: CMDx::Result::FAILED,
          metadata: {
            reason: "first_name delegates to undefined method fake. title delegates to undefined method fake",
            messages: {
              first_name: ["delegates to undefined method fake"],
              title: ["delegates to undefined method fake"]
            }
          }
        )
      end
    end

    context "when required parameter is missing" do
      let(:ctx) { {} }
      let(:simulation_task) do
        Class.new(SimulationTask) do
          required :first_name
          optional :title

          def call
            context.full_name = [title, first_name]
          end
        end
      end

      it "fails validation" do
        expect(result).to be_failed
        expect(result).to have_attributes(
          state: CMDx::Result::INTERRUPTED,
          status: CMDx::Result::FAILED,
          metadata: {
            reason: "first_name is a required parameter",
            messages: { first_name: ["is a required parameter"] }
          }
        )
      end
    end
  end

  describe "#coercions" do
    let(:simulation_task) do
      Class.new(SimulationTask) do
        required :first_name, type: :integer
        optional :title, type: %i[integer float]

        def call
          context.full_name = [title, first_name]
        end
      end
    end

    it "fails validation" do
      expect(result).to be_failed
      expect(result).to have_attributes(
        state: CMDx::Result::INTERRUPTED,
        status: CMDx::Result::FAILED,
        metadata: {
          reason: "first_name could not coerce into an integer. title could not coerce into one of: integer, float",
          messages: {
            first_name: ["could not coerce into an integer"],
            title: ["could not coerce into one of: integer, float"]
          }
        }
      )
    end
  end

  describe "#validations" do
    let(:simulation_task) do
      Class.new(SimulationTask) do
        required :first_name, presence: true
        optional :last_name, presence: true
      end
    end

    context "when both required and optional parameters given" do
      let(:ctx) do
        {
          first_name: nil,
          last_name: nil
        }
      end

      it "fails validation" do
        expect(result).to be_failed
        expect(result).to have_attributes(
          state: CMDx::Result::INTERRUPTED,
          status: CMDx::Result::FAILED,
          metadata: {
            reason: "first_name cannot be empty. last_name cannot be empty",
            messages: {
              first_name: ["cannot be empty"],
              last_name: ["cannot be empty"]
            }
          }
        )
      end
    end

    context "when optional parameter is not passed" do
      let(:ctx) do
        { first_name: nil }
      end

      it "fails validation" do
        expect(result).to be_failed
        expect(result).to have_attributes(
          state: CMDx::Result::INTERRUPTED,
          status: CMDx::Result::FAILED,
          metadata: {
            reason: "first_name cannot be empty",
            messages: {
              first_name: ["cannot be empty"]
            }
          }
        )
      end
    end

    context "with allow_nil" do
      let(:simulation_task) do
        Class.new(SimulationTask) do
          required :first_name, presence: { allow_nil: true }
          optional :last_name, presence: { allow_nil: false }

          private

          def run_validation?
            false
          end
        end
      end

      let(:ctx) do
        {
          first_name: nil,
          last_name: ""
        }
      end

      it "fails validation" do
        expect(result).to be_failed
        expect(result).to have_attributes(
          state: CMDx::Result::INTERRUPTED,
          status: CMDx::Result::FAILED,
          metadata: {
            reason: "last_name cannot be empty",
            messages: {
              last_name: ["cannot be empty"]
            }
          }
        )
      end
    end

    context "with conditional" do
      let(:simulation_task) do
        Class.new(SimulationTask) do
          required :first_name, presence: { if: proc { true } }
          optional :last_name, presence: { if: :run_validation? }

          private

          def run_validation?
            false
          end
        end
      end

      let(:ctx) do
        {
          first_name: nil,
          last_name: ""
        }
      end

      it "fails validation" do
        expect(result).to be_failed
        expect(result).to have_attributes(
          state: CMDx::Result::INTERRUPTED,
          status: CMDx::Result::FAILED,
          metadata: {
            reason: "first_name cannot be empty",
            messages: {
              first_name: ["cannot be empty"]
            }
          }
        )
      end
    end
  end

end
