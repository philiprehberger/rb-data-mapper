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
        expect(result).to eq([
          { full_name: "Alice", years: 30 },
          { full_name: "Bob", years: 25 }
        ])
      end
    end
  end
end
