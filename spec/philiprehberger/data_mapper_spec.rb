# frozen_string_literal: true

require "spec_helper"

RSpec.describe Philiprehberger::DataMapper do
  describe ".define" do
    it "returns a Mapping instance" do
      mapping = described_class.define { field :name }
      expect(mapping).to be_a(Philiprehberger::DataMapper::Mapping)
    end
  end

  describe Philiprehberger::DataMapper::Mapping do
    describe "#map" do
      it "renames fields using from:" do
        mapping = described_class.new { field :full_name, from: :name }
        result = mapping.map({ name: "Alice" })
        expect(result).to eq({ full_name: "Alice" })
      end

      it "uses target name when from: is omitted" do
        mapping = described_class.new { field :name }
        result = mapping.map({ name: "Bob" })
        expect(result).to eq({ name: "Bob" })
      end

      it "applies a transform block" do
        mapping = described_class.new do
          field :name, from: :raw_name, &:upcase
        end
        result = mapping.map({ raw_name: "alice" })
        expect(result).to eq({ name: "ALICE" })
      end

      it "uses default when source key is missing" do
        mapping = described_class.new { field :role, default: "guest" }
        result = mapping.map({})
        expect(result).to eq({ role: "guest" })
      end

      it "uses default when source value is nil" do
        mapping = described_class.new { field :role, default: "guest" }
        result = mapping.map({ role: nil })
        expect(result).to eq({ role: "guest" })
      end

      it "maps multiple fields at once" do
        mapping = described_class.new do
          field :first, from: :a
          field :second, from: :b
        end
        result = mapping.map({ a: 1, b: 2 })
        expect(result).to eq({ first: 1, second: 2 })
      end
    end

    describe "#map_all" do
      it "maps an array of hashes" do
        mapping = described_class.new { field :name, from: :n }
        input = [{ n: "Alice" }, { n: "Bob" }]
        result = mapping.map_all(input)
        expect(result).to eq([{ name: "Alice" }, { name: "Bob" }])
      end
    end

    describe "#from_csv" do
      it "parses CSV and maps each row" do
        csv = "name,age\nAlice,30\nBob,25\n"
        mapping = described_class.new do
          field :full_name, from: :name
          field :years, from: :age, &:to_i
        end
        result = mapping.from_csv(csv)
        expect(result).to eq(
          [
            { full_name: "Alice", years: 30 },
            { full_name: "Bob", years: 25 }
          ]
        )
      end
    end

    describe "nested key access" do
      it "digs into nested hashes with dot notation" do
        mapping = described_class.new do
          field :city, from: "address.city"
        end
        result = mapping.map({ address: { city: "Vienna" } })
        expect(result).to eq({ city: "Vienna" })
      end

      it "returns nil for missing nested keys" do
        mapping = described_class.new do
          field :zip, from: "address.zip", default: "00000"
        end
        result = mapping.map({ address: { city: "Vienna" } })
        expect(result).to eq({ zip: "00000" })
      end

      it "supports deeply nested paths" do
        mapping = described_class.new do
          field :street, from: "user.address.street.name"
        end
        data = { user: { address: { street: { name: "Main St" } } } }
        result = mapping.map(data)
        expect(result).to eq({ street: "Main St" })
      end
    end

    describe "type coercion" do
      it "coerces to :string" do
        mapping = described_class.new { field :val, type: :string }
        result = mapping.map({ val: 42 })
        expect(result).to eq({ val: "42" })
      end

      it "coerces to :integer" do
        mapping = described_class.new { field :val, type: :integer }
        result = mapping.map({ val: "99" })
        expect(result).to eq({ val: 99 })
      end

      it "coerces to :float" do
        mapping = described_class.new { field :val, type: :float }
        result = mapping.map({ val: "3.14" })
        expect(result).to eq({ val: 3.14 })
      end

      it "coerces 'true' to boolean true" do
        mapping = described_class.new { field :val, type: :boolean }
        expect(mapping.map({ val: "true" })).to eq({ val: true })
        expect(mapping.map({ val: "1" })).to eq({ val: true })
        expect(mapping.map({ val: "yes" })).to eq({ val: true })
      end

      it "coerces 'false' to boolean false" do
        mapping = described_class.new { field :val, type: :boolean }
        expect(mapping.map({ val: "false" })).to eq({ val: false })
        expect(mapping.map({ val: "0" })).to eq({ val: false })
        expect(mapping.map({ val: "no" })).to eq({ val: false })
      end

      it "combines type coercion with from: rename" do
        mapping = described_class.new do
          field :age, from: :raw_age, type: :integer
        end
        result = mapping.map({ raw_age: "25" })
        expect(result).to eq({ age: 25 })
      end

      it "applies coercion after transform" do
        mapping = described_class.new do
          field :score, type: :integer do |v|
            v.gsub(",", "")
          end
        end
        result = mapping.map({ score: "1,000" })
        expect(result).to eq({ score: 1000 })
      end
    end

    describe "#from_json" do
      it "maps a single JSON object" do
        json = '{"name": "Alice", "age": 30}'
        mapping = described_class.new do
          field :name
          field :years, from: :age
        end
        result = mapping.from_json(json)
        expect(result).to eq({ name: "Alice", years: 30 })
      end

      it "maps a JSON array of objects" do
        json = '[{"n": "Alice"}, {"n": "Bob"}]'
        mapping = described_class.new { field :name, from: :n }
        result = mapping.from_json(json)
        expect(result).to eq([{ name: "Alice" }, { name: "Bob" }])
      end
    end
  end
end
