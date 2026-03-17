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

    describe "conditional mapping" do
      it "includes field when condition is met" do
        mapping = described_class.new do
          field :role, from: :raw_role, if: ->(record) { record[:admin] }
        end
        result = mapping.map({ raw_role: "superuser", admin: true })
        expect(result).to eq({ role: "superuser" })
      end

      it "excludes field when condition is not met" do
        mapping = described_class.new do
          field :role, from: :raw_role, if: ->(record) { record[:admin] }
        end
        result = mapping.map({ raw_role: "superuser", admin: false })
        expect(result).to eq({})
      end

      it "mixes conditional and unconditional fields" do
        mapping = described_class.new do
          field :name
          field :role, from: :raw_role, if: ->(record) { record[:admin] }
        end
        result = mapping.map({ name: "Alice", raw_role: "admin", admin: false })
        expect(result).to eq({ name: "Alice" })
      end

      it "always includes fields without a condition" do
        mapping = described_class.new do
          field :name
        end
        result = mapping.map({ name: "Bob" })
        expect(result).to eq({ name: "Bob" })
      end
    end

    describe "computed fields" do
      it "derives a field from the full record" do
        mapping = described_class.new do
          computed(:full_name) { |record| "#{record[:first]} #{record[:last]}" }
        end
        result = mapping.map({ first: "Alice", last: "Smith" })
        expect(result).to eq({ full_name: "Alice Smith" })
      end

      it "combines regular and computed fields" do
        mapping = described_class.new do
          field :email
          computed(:greeting) { |record| "Hello, #{record[:name]}!" }
        end
        result = mapping.map({ email: "a@b.com", name: "Alice" })
        expect(result).to eq({ email: "a@b.com", greeting: "Hello, Alice!" })
      end

      it "supports multiple computed fields" do
        mapping = described_class.new do
          computed(:full_name) { |record| "#{record[:first]} #{record[:last]}" }
          computed(:initials) { |record| "#{record[:first][0]}#{record[:last][0]}" }
        end
        result = mapping.map({ first: "Alice", last: "Smith" })
        expect(result).to eq({ full_name: "Alice Smith", initials: "AS" })
      end
    end

    describe "collection mapping (array_field)" do
      it "splits a string value into an array" do
        mapping = described_class.new do
          array_field :tags, from: :tag_csv, split: ","
        end
        result = mapping.map({ tag_csv: "ruby,rails,gem" })
        expect(result).to eq({ tags: %w[ruby rails gem] })
      end

      it "uses comma as default delimiter" do
        mapping = described_class.new do
          array_field :tags, from: :tag_csv
        end
        result = mapping.map({ tag_csv: "a,b,c" })
        expect(result).to eq({ tags: %w[a b c] })
      end

      it "supports custom delimiter" do
        mapping = described_class.new do
          array_field :items, from: :item_str, split: "|"
        end
        result = mapping.map({ item_str: "one|two|three" })
        expect(result).to eq({ items: %w[one two three] })
      end

      it "applies transform after splitting" do
        mapping = described_class.new do
          array_field :tags, from: :tag_csv, split: "," do |arr|
            arr.map(&:strip)
          end
        end
        result = mapping.map({ tag_csv: "ruby, rails, gem" })
        expect(result).to eq({ tags: %w[ruby rails gem] })
      end

      it "handles nil source value with default" do
        mapping = described_class.new do
          array_field :tags, from: :tag_csv, split: ","
        end
        result = mapping.map({})
        expect(result).to eq({ tags: nil })
      end
    end

    describe "reverse mapping" do
      it "transforms output back to input schema" do
        mapping = described_class.new do
          field :full_name, from: :name
          field :years, from: :age
        end
        output = { full_name: "Alice", years: 30 }
        result = mapping.reverse(output)
        expect(result).to eq({ name: "Alice", age: 30 })
      end

      it "only includes fields present in the output" do
        mapping = described_class.new do
          field :full_name, from: :name
          field :years, from: :age
        end
        output = { full_name: "Alice" }
        result = mapping.reverse(output)
        expect(result).to eq({ name: "Alice" })
      end

      it "handles same-name fields (no rename)" do
        mapping = described_class.new do
          field :name
          field :age
        end
        output = { name: "Bob", age: 25 }
        result = mapping.reverse(output)
        expect(result).to eq({ name: "Bob", age: 25 })
      end

      it "returns an empty hash for unknown keys" do
        mapping = described_class.new do
          field :full_name, from: :name
        end
        result = mapping.reverse({ unknown: "value" })
        expect(result).to eq({})
      end
    end

    describe "validation" do
      it "returns a valid result when all validations pass" do
        mapping = described_class.new do
          field :age, from: :raw_age, type: :integer, validate: ->(v) { v > 0 }
        end
        result = mapping.map_with_validation({ raw_age: "25" })
        expect(result).to be_valid
        expect(result.value).to eq({ age: 25 })
        expect(result.errors).to be_empty
      end

      it "returns an invalid result when validation fails" do
        mapping = described_class.new do
          field :age, from: :raw_age, type: :integer, validate: ->(v) { v > 0 }
        end
        result = mapping.map_with_validation({ raw_age: "-1" })
        expect(result).not_to be_valid
        expect(result.value).to eq({ age: -1 })
        expect(result.errors).to eq([{ field: :age, value: -1 }])
      end

      it "collects multiple validation errors" do
        mapping = described_class.new do
          field :age, type: :integer, validate: ->(v) { v > 0 }
          field :name, validate: ->(v) { !v.nil? && !v.empty? }
        end
        result = mapping.map_with_validation({ age: "-5", name: "" })
        expect(result).not_to be_valid
        expect(result.errors.length).to eq(2)
        expect(result.errors).to include({ field: :age, value: -5 })
        expect(result.errors).to include({ field: :name, value: "" })
      end

      it "includes computed fields in validation result" do
        mapping = described_class.new do
          field :name
          computed(:greeting) { |r| "Hi, #{r[:name]}" }
        end
        result = mapping.map_with_validation({ name: "Alice" })
        expect(result).to be_valid
        expect(result.value).to eq({ name: "Alice", greeting: "Hi, Alice" })
      end

      it "fields without validate: always pass" do
        mapping = described_class.new do
          field :name
          field :age, type: :integer, validate: ->(v) { v > 0 }
        end
        result = mapping.map_with_validation({ name: "Alice", age: "30" })
        expect(result).to be_valid
        expect(result.value).to eq({ name: "Alice", age: 30 })
      end
    end
  end
end
