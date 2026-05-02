# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::DataMapper do
  describe '.define' do
    it 'returns a Mapping instance' do
      mapping = described_class.define { field :name }
      expect(mapping).to be_a(Philiprehberger::DataMapper::Mapping)
    end
  end

  describe Philiprehberger::DataMapper::Mapping do
    describe '#map' do
      it 'renames fields using from:' do
        mapping = described_class.new { field :full_name, from: :name }
        result = mapping.map({ name: 'Alice' })
        expect(result).to eq({ full_name: 'Alice' })
      end

      it 'uses target name when from: is omitted' do
        mapping = described_class.new { field :name }
        result = mapping.map({ name: 'Bob' })
        expect(result).to eq({ name: 'Bob' })
      end

      it 'applies a transform block' do
        mapping = described_class.new do
          field :name, from: :raw_name, &:upcase
        end
        result = mapping.map({ raw_name: 'alice' })
        expect(result).to eq({ name: 'ALICE' })
      end

      it 'uses default when source key is missing' do
        mapping = described_class.new { field :role, default: 'guest' }
        result = mapping.map({})
        expect(result).to eq({ role: 'guest' })
      end

      it 'uses default when source value is nil' do
        mapping = described_class.new { field :role, default: 'guest' }
        result = mapping.map({ role: nil })
        expect(result).to eq({ role: 'guest' })
      end

      it 'maps multiple fields at once' do
        mapping = described_class.new do
          field :first, from: :a
          field :second, from: :b
        end
        result = mapping.map({ a: 1, b: 2 })
        expect(result).to eq({ first: 1, second: 2 })
      end
    end

    describe '#map_all' do
      it 'maps an array of hashes' do
        mapping = described_class.new { field :name, from: :n }
        input = [{ n: 'Alice' }, { n: 'Bob' }]
        result = mapping.map_all(input)
        expect(result).to eq([{ name: 'Alice' }, { name: 'Bob' }])
      end
    end

    describe '#map_lazy' do
      it 'returns an Enumerator::Lazy' do
        mapping = described_class.new { field :name, from: :n }
        expect(mapping.map_lazy([{ n: 'Alice' }])).to be_a(Enumerator::Lazy)
      end

      it 'supports .first(n) without forcing full enumeration' do
        mapping = described_class.new { field :name, from: :n }
        input = [{ n: 'Alice' }, { n: 'Bob' }, { n: 'Carol' }]
        expect(mapping.map_lazy(input).first(2)).to eq(
          [{ name: 'Alice' }, { name: 'Bob' }]
        )
      end

      it 'produces values equal to #map element-wise' do
        mapping = described_class.new do
          field :name, from: :n
          field :years, from: :age, &:to_i
        end
        input = [{ n: 'Alice', age: '30' }, { n: 'Bob', age: '25' }]
        expected = input.map { |row| mapping.map(row) }
        expect(mapping.map_lazy(input).to_a).to eq(expected)
      end

      it 'chains .select and remains lazy' do
        mapping = described_class.new { field :years, from: :age, &:to_i }
        input = [{ age: '10' }, { age: '20' }, { age: '30' }]
        chained = mapping.map_lazy(input).select { |row| row[:years] >= 20 }
        expect(chained).to be_a(Enumerator::Lazy)
        expect(chained.to_a).to eq([{ years: 20 }, { years: 30 }])
      end

      it 'terminates on an infinite enumerable with .first(n)' do
        mapping = described_class.new { field :id }
        infinite = (1..).lazy.map { |i| { 'id' => i } }
        expect(mapping.map_lazy(infinite).first(3)).to eq(
          [{ id: 1 }, { id: 2 }, { id: 3 }]
        )
      end
    end

    describe '#from_csv' do
      it 'parses CSV and maps each row' do
        csv = "name,age\nAlice,30\nBob,25\n"
        mapping = described_class.new do
          field :full_name, from: :name
          field :years, from: :age, &:to_i
        end
        result = mapping.from_csv(csv)
        expect(result).to eq(
          [
            { full_name: 'Alice', years: 30 },
            { full_name: 'Bob', years: 25 }
          ]
        )
      end
    end

    describe 'nested key access' do
      it 'digs into nested hashes with dot notation' do
        mapping = described_class.new do
          field :city, from: 'address.city'
        end
        result = mapping.map({ address: { city: 'Vienna' } })
        expect(result).to eq({ city: 'Vienna' })
      end

      it 'returns nil for missing nested keys' do
        mapping = described_class.new do
          field :zip, from: 'address.zip', default: '00000'
        end
        result = mapping.map({ address: { city: 'Vienna' } })
        expect(result).to eq({ zip: '00000' })
      end

      it 'supports deeply nested paths' do
        mapping = described_class.new do
          field :street, from: 'user.address.street.name'
        end
        data = { user: { address: { street: { name: 'Main St' } } } }
        result = mapping.map(data)
        expect(result).to eq({ street: 'Main St' })
      end
    end

    describe 'type coercion' do
      it 'coerces to :string' do
        mapping = described_class.new { field :val, type: :string }
        result = mapping.map({ val: 42 })
        expect(result).to eq({ val: '42' })
      end

      it 'coerces to :integer' do
        mapping = described_class.new { field :val, type: :integer }
        result = mapping.map({ val: '99' })
        expect(result).to eq({ val: 99 })
      end

      it 'coerces to :float' do
        mapping = described_class.new { field :val, type: :float }
        result = mapping.map({ val: '3.14' })
        expect(result).to eq({ val: 3.14 })
      end

      it "coerces 'true' to boolean true" do
        mapping = described_class.new { field :val, type: :boolean }
        expect(mapping.map({ val: 'true' })).to eq({ val: true })
        expect(mapping.map({ val: '1' })).to eq({ val: true })
        expect(mapping.map({ val: 'yes' })).to eq({ val: true })
      end

      it "coerces 'false' to boolean false" do
        mapping = described_class.new { field :val, type: :boolean }
        expect(mapping.map({ val: 'false' })).to eq({ val: false })
        expect(mapping.map({ val: '0' })).to eq({ val: false })
        expect(mapping.map({ val: 'no' })).to eq({ val: false })
      end

      it 'combines type coercion with from: rename' do
        mapping = described_class.new do
          field :age, from: :raw_age, type: :integer
        end
        result = mapping.map({ raw_age: '25' })
        expect(result).to eq({ age: 25 })
      end

      it 'applies coercion after transform' do
        mapping = described_class.new do
          field :score, type: :integer do |v|
            v.gsub(',', '')
          end
        end
        result = mapping.map({ score: '1,000' })
        expect(result).to eq({ score: 1000 })
      end
    end

    describe '#from_json' do
      it 'maps a single JSON object' do
        json = '{"name": "Alice", "age": 30}'
        mapping = described_class.new do
          field :name
          field :years, from: :age
        end
        result = mapping.from_json(json)
        expect(result).to eq({ name: 'Alice', years: 30 })
      end

      it 'maps a JSON array of objects' do
        json = '[{"n": "Alice"}, {"n": "Bob"}]'
        mapping = described_class.new { field :name, from: :n }
        result = mapping.from_json(json)
        expect(result).to eq([{ name: 'Alice' }, { name: 'Bob' }])
      end
    end

    describe 'conditional mapping' do
      it 'includes field when condition is met' do
        mapping = described_class.new do
          field :role, from: :raw_role, if: ->(record) { record[:admin] }
        end
        result = mapping.map({ raw_role: 'superuser', admin: true })
        expect(result).to eq({ role: 'superuser' })
      end

      it 'excludes field when condition is not met' do
        mapping = described_class.new do
          field :role, from: :raw_role, if: ->(record) { record[:admin] }
        end
        result = mapping.map({ raw_role: 'superuser', admin: false })
        expect(result).to eq({})
      end

      it 'mixes conditional and unconditional fields' do
        mapping = described_class.new do
          field :name
          field :role, from: :raw_role, if: ->(record) { record[:admin] }
        end
        result = mapping.map({ name: 'Alice', raw_role: 'admin', admin: false })
        expect(result).to eq({ name: 'Alice' })
      end

      it 'always includes fields without a condition' do
        mapping = described_class.new do
          field :name
        end
        result = mapping.map({ name: 'Bob' })
        expect(result).to eq({ name: 'Bob' })
      end
    end

    describe 'computed fields' do
      it 'derives a field from the full record' do
        mapping = described_class.new do
          computed(:full_name) { |record| "#{record[:first]} #{record[:last]}" }
        end
        result = mapping.map({ first: 'Alice', last: 'Smith' })
        expect(result).to eq({ full_name: 'Alice Smith' })
      end

      it 'combines regular and computed fields' do
        mapping = described_class.new do
          field :email
          computed(:greeting) { |record| "Hello, #{record[:name]}!" }
        end
        result = mapping.map({ email: 'a@b.com', name: 'Alice' })
        expect(result).to eq({ email: 'a@b.com', greeting: 'Hello, Alice!' })
      end

      it 'supports multiple computed fields' do
        mapping = described_class.new do
          computed(:full_name) { |record| "#{record[:first]} #{record[:last]}" }
          computed(:initials) { |record| "#{record[:first][0]}#{record[:last][0]}" }
        end
        result = mapping.map({ first: 'Alice', last: 'Smith' })
        expect(result).to eq({ full_name: 'Alice Smith', initials: 'AS' })
      end
    end

    describe 'collection mapping (array_field)' do
      it 'splits a string value into an array' do
        mapping = described_class.new do
          array_field :tags, from: :tag_csv, split: ','
        end
        result = mapping.map({ tag_csv: 'ruby,rails,gem' })
        expect(result).to eq({ tags: %w[ruby rails gem] })
      end

      it 'uses comma as default delimiter' do
        mapping = described_class.new do
          array_field :tags, from: :tag_csv
        end
        result = mapping.map({ tag_csv: 'a,b,c' })
        expect(result).to eq({ tags: %w[a b c] })
      end

      it 'supports custom delimiter' do
        mapping = described_class.new do
          array_field :items, from: :item_str, split: '|'
        end
        result = mapping.map({ item_str: 'one|two|three' })
        expect(result).to eq({ items: %w[one two three] })
      end

      it 'applies transform after splitting' do
        mapping = described_class.new do
          array_field :tags, from: :tag_csv, split: ',' do |arr|
            arr.map(&:strip)
          end
        end
        result = mapping.map({ tag_csv: 'ruby, rails, gem' })
        expect(result).to eq({ tags: %w[ruby rails gem] })
      end

      it 'handles nil source value with default' do
        mapping = described_class.new do
          array_field :tags, from: :tag_csv, split: ','
        end
        result = mapping.map({})
        expect(result).to eq({ tags: nil })
      end
    end

    describe 'reverse mapping' do
      it 'transforms output back to input schema' do
        mapping = described_class.new do
          field :full_name, from: :name
          field :years, from: :age
        end
        output = { full_name: 'Alice', years: 30 }
        result = mapping.reverse(output)
        expect(result).to eq({ name: 'Alice', age: 30 })
      end

      it 'only includes fields present in the output' do
        mapping = described_class.new do
          field :full_name, from: :name
          field :years, from: :age
        end
        output = { full_name: 'Alice' }
        result = mapping.reverse(output)
        expect(result).to eq({ name: 'Alice' })
      end

      it 'handles same-name fields (no rename)' do
        mapping = described_class.new do
          field :name
          field :age
        end
        output = { name: 'Bob', age: 25 }
        result = mapping.reverse(output)
        expect(result).to eq({ name: 'Bob', age: 25 })
      end

      it 'returns an empty hash for unknown keys' do
        mapping = described_class.new do
          field :full_name, from: :name
        end
        result = mapping.reverse({ unknown: 'value' })
        expect(result).to eq({})
      end
    end

    describe 'validation' do
      it 'returns a valid result when all validations pass' do
        mapping = described_class.new do
          field :age, from: :raw_age, type: :integer, validate: ->(v) { v > 0 }
        end
        result = mapping.map_with_validation({ raw_age: '25' })
        expect(result).to be_valid
        expect(result.value).to eq({ age: 25 })
        expect(result.errors).to be_empty
      end

      it 'returns an invalid result when validation fails' do
        mapping = described_class.new do
          field :age, from: :raw_age, type: :integer, validate: ->(v) { v > 0 }
        end
        result = mapping.map_with_validation({ raw_age: '-1' })
        expect(result).not_to be_valid
        expect(result.value).to eq({ age: -1 })
        expect(result.errors).to eq([{ field: :age, value: -1 }])
      end

      it 'collects multiple validation errors' do
        mapping = described_class.new do
          field :age, type: :integer, validate: ->(v) { v > 0 }
          field :name, validate: ->(v) { !v.nil? && !v.empty? }
        end
        result = mapping.map_with_validation({ age: '-5', name: '' })
        expect(result).not_to be_valid
        expect(result.errors.length).to eq(2)
        expect(result.errors).to include({ field: :age, value: -5 })
        expect(result.errors).to include({ field: :name, value: '' })
      end

      it 'includes computed fields in validation result' do
        mapping = described_class.new do
          field :name
          computed(:greeting) { |r| "Hi, #{r[:name]}" }
        end
        result = mapping.map_with_validation({ name: 'Alice' })
        expect(result).to be_valid
        expect(result.value).to eq({ name: 'Alice', greeting: 'Hi, Alice' })
      end

      it 'fields without validate: always pass' do
        mapping = described_class.new do
          field :name
          field :age, type: :integer, validate: ->(v) { v > 0 }
        end
        result = mapping.map_with_validation({ name: 'Alice', age: '30' })
        expect(result).to be_valid
        expect(result.value).to eq({ name: 'Alice', age: 30 })
      end

      it 'skips conditional fields that are excluded from validation' do
        mapping = described_class.new do
          field :name
          field :role, validate: ->(v) { !v.nil? }, if: ->(r) { r[:admin] }
        end
        result = mapping.map_with_validation({ name: 'Alice', role: nil, admin: false })
        expect(result).to be_valid
        expect(result.value).to eq({ name: 'Alice' })
      end

      it 'applies default values before validation' do
        mapping = described_class.new do
          field :status, default: 'active', validate: ->(v) { %w[active inactive].include?(v) }
        end
        result = mapping.map_with_validation({})
        expect(result).to be_valid
        expect(result.value).to eq({ status: 'active' })
      end
    end

    describe 'empty and edge-case mappings' do
      it 'returns an empty hash when no fields are defined' do
        mapping = described_class.new {}
        result = mapping.map({ name: 'Alice', age: 30 })
        expect(result).to eq({})
      end

      it 'creates a mapping without a block' do
        mapping = described_class.new
        result = mapping.map({ name: 'Alice' })
        expect(result).to eq({})
      end

      it 'maps an empty hash' do
        mapping = described_class.new { field :name }
        result = mapping.map({})
        expect(result).to eq({ name: nil })
      end

      it 'maps an empty array with map_all' do
        mapping = described_class.new { field :name }
        result = mapping.map_all([])
        expect(result).to eq([])
      end
    end

    describe 'string key access' do
      it 'falls back to string keys when symbol keys are absent' do
        mapping = described_class.new { field :name }
        result = mapping.map({ 'name' => 'Alice' })
        expect(result).to eq({ name: 'Alice' })
      end

      it 'prefers symbol keys over string keys' do
        mapping = described_class.new { field :name }
        result = mapping.map({ name: 'Symbol', 'name' => 'String' })
        expect(result).to eq({ name: 'Symbol' })
      end
    end

    describe 'nested key edge cases' do
      it 'returns nil when intermediate key is not a hash' do
        mapping = described_class.new do
          field :city, from: 'address.city'
        end
        result = mapping.map({ address: 'not a hash' })
        expect(result).to eq({ city: nil })
      end

      it 'returns nil when top-level key is missing for nested path' do
        mapping = described_class.new do
          field :city, from: 'address.city'
        end
        result = mapping.map({})
        expect(result).to eq({ city: nil })
      end

      it 'navigates nested hashes with string keys' do
        mapping = described_class.new do
          field :city, from: 'address.city'
        end
        result = mapping.map({ 'address' => { 'city' => 'Berlin' } })
        expect(result).to eq({ city: 'Berlin' })
      end
    end

    describe 'type coercion edge cases' do
      it 'returns nil when coercing a nil value' do
        mapping = described_class.new { field :val, type: :integer }
        result = mapping.map({ val: nil })
        expect(result).to eq({ val: nil })
      end

      it 'passes value through for an unknown type' do
        mapping = described_class.new { field :val, type: :unknown }
        result = mapping.map({ val: 'hello' })
        expect(result).to eq({ val: 'hello' })
      end

      it 'returns boolean true as-is without string coercion' do
        mapping = described_class.new { field :val, type: :boolean }
        result = mapping.map({ val: true })
        expect(result).to eq({ val: true })
      end

      it 'returns boolean false as-is without string coercion' do
        mapping = described_class.new { field :val, type: :boolean }
        result = mapping.map({ val: false })
        expect(result).to eq({ val: false })
      end

      it 'returns unrecognized boolean values unchanged' do
        mapping = described_class.new { field :val, type: :boolean }
        result = mapping.map({ val: 'maybe' })
        expect(result).to eq({ val: 'maybe' })
      end

      it 'coerces case-insensitive boolean strings' do
        mapping = described_class.new { field :val, type: :boolean }
        expect(mapping.map({ val: 'TRUE' })).to eq({ val: true })
        expect(mapping.map({ val: 'Yes' })).to eq({ val: true })
        expect(mapping.map({ val: 'FALSE' })).to eq({ val: false })
        expect(mapping.map({ val: 'No' })).to eq({ val: false })
      end
    end

    describe 'array_field edge cases' do
      it 'does not split non-string values' do
        mapping = described_class.new do
          array_field :tags, from: :tag_list
        end
        result = mapping.map({ tag_list: %w[already an array] })
        expect(result).to eq({ tags: %w[already an array] })
      end
    end

    describe 'reverse mapping edge cases' do
      it 'ignores computed fields during reverse' do
        mapping = described_class.new do
          field :first
          field :last
          computed(:full_name) { |r| "#{r[:first]} #{r[:last]}" }
        end
        result = mapping.reverse({ first: 'Alice', last: 'Smith', full_name: 'Alice Smith' })
        expect(result).to eq({ first: 'Alice', last: 'Smith' })
      end
    end

    describe '#from_json edge cases' do
      it 'symbolizes nested keys in JSON objects' do
        json = '{"user": {"name": "Alice", "address": {"city": "Vienna"}}}'
        mapping = described_class.new do
          field :city, from: 'user.address.city'
        end
        result = mapping.from_json(json)
        expect(result).to eq({ city: 'Vienna' })
      end

      it 'maps a JSON array with nested key access' do
        json = '[{"user": {"name": "Alice"}}, {"user": {"name": "Bob"}}]'
        mapping = described_class.new do
          field :name, from: 'user.name'
        end
        result = mapping.from_json(json)
        expect(result).to eq([{ name: 'Alice' }, { name: 'Bob' }])
      end
    end

    describe 'type coercion error paths' do
      it 'raises ArgumentError when coercing a non-numeric string to :integer' do
        mapping = described_class.new { field :val, type: :integer }
        expect { mapping.map({ val: 'not_a_number' }) }.to raise_error(ArgumentError)
      end

      it 'raises ArgumentError when coercing a non-numeric string to :float' do
        mapping = described_class.new { field :val, type: :float }
        expect { mapping.map({ val: 'not_a_float' }) }.to raise_error(ArgumentError)
      end

      it 'coerces an integer value to :float' do
        mapping = described_class.new { field :val, type: :float }
        result = mapping.map({ val: 42 })
        expect(result).to eq({ val: 42.0 })
      end

      it 'coerces a float value to :string' do
        mapping = described_class.new { field :val, type: :string }
        result = mapping.map({ val: 3.14 })
        expect(result).to eq({ val: '3.14' })
      end
    end

    describe 'default combined with transform' do
      it 'applies default before transform' do
        mapping = described_class.new do
          field :name, default: 'anonymous', &:upcase
        end
        result = mapping.map({})
        expect(result).to eq({ name: 'ANONYMOUS' })
      end

      it 'applies default before type coercion' do
        mapping = described_class.new do
          field :count, default: '10', type: :integer
        end
        result = mapping.map({})
        expect(result).to eq({ count: 10 })
      end
    end

    describe '#map_all with computed fields' do
      it 'applies computed fields to each record' do
        mapping = described_class.new do
          field :name
          computed(:upper_name) { |r| r[:name].upcase }
        end
        result = mapping.map_all([{ name: 'Alice' }, { name: 'Bob' }])
        expect(result).to eq([
                               { name: 'Alice', upper_name: 'ALICE' },
                               { name: 'Bob', upper_name: 'BOB' }
                             ])
      end
    end

    describe 'computed fields edge cases' do
      it 'computed field can access nil values in the record' do
        mapping = described_class.new do
          computed(:status) { |r| r[:active] ? 'active' : 'inactive' }
        end
        result = mapping.map({ active: nil })
        expect(result).to eq({ status: 'inactive' })
      end

      it 'computed field overwrites a regular field with the same target' do
        mapping = described_class.new do
          field :name
          computed(:name) { |_r| 'computed_value' }
        end
        result = mapping.map({ name: 'original' })
        expect(result).to eq({ name: 'computed_value' })
      end
    end

    describe 'conditional mapping edge cases' do
      it 'excludes conditional field when condition key is missing from record' do
        mapping = described_class.new do
          field :secret, if: ->(r) { r[:authorized] }
        end
        result = mapping.map({ secret: 'data' })
        expect(result).to eq({})
      end

      it 'includes conditional field with default when condition is met but value is missing' do
        mapping = described_class.new do
          field :role, default: 'member', if: ->(r) { r[:logged_in] }
        end
        result = mapping.map({ logged_in: true })
        expect(result).to eq({ role: 'member' })
      end
    end

    describe 'validation edge cases' do
      it 'validates array_field values' do
        mapping = described_class.new do
          array_field :tags, from: :tag_csv, split: ',', validate: ->(v) { v.is_a?(Array) && v.length > 1 }
        end
        result = mapping.map_with_validation({ tag_csv: 'solo' })
        expect(result).not_to be_valid
        expect(result.errors).to eq([{ field: :tags, value: ['solo'] }])
      end

      it 'returns valid result for empty mapping with no fields' do
        mapping = described_class.new {}
        result = mapping.map_with_validation({ anything: 'here' })
        expect(result).to be_valid
        expect(result.value).to eq({})
        expect(result.errors).to be_empty
      end

      it 'validates field with transform and type coercion combined' do
        mapping = described_class.new do
          field :score, from: :raw, type: :integer, validate: ->(v) { v.between?(0, 100) }, &:strip
        end
        result = mapping.map_with_validation({ raw: ' 150 ' })
        expect(result).not_to be_valid
        expect(result.value).to eq({ score: 150 })
      end
    end

    describe 'reverse mapping additional cases' do
      it 'reverse maps fields with from: rename on multiple fields' do
        mapping = described_class.new do
          field :display_name, from: :name
          field :email_address, from: :email
          field :user_age, from: :age
        end
        output = { display_name: 'Alice', email_address: 'a@b.com', user_age: 30 }
        result = mapping.reverse(output)
        expect(result).to eq({ name: 'Alice', email: 'a@b.com', age: 30 })
      end

      it 'reverse maps when output contains nil values' do
        mapping = described_class.new do
          field :full_name, from: :name
        end
        result = mapping.reverse({ full_name: nil })
        expect(result).to eq({ name: nil })
      end
    end

    describe '#from_csv edge cases' do
      it 'handles CSV with only headers and no data rows' do
        csv = "name,age\n"
        mapping = described_class.new do
          field :name
          field :age, type: :integer
        end
        result = mapping.from_csv(csv)
        expect(result).to eq([])
      end

      it 'applies type coercion to CSV values' do
        csv = "active,count\ntrue,5\nfalse,10\n"
        mapping = described_class.new do
          field :active, type: :boolean
          field :count, type: :integer
        end
        result = mapping.from_csv(csv)
        expect(result).to eq([
                               { active: true, count: 5 },
                               { active: false, count: 10 }
                             ])
      end
    end

    describe Philiprehberger::DataMapper::MappingResult do
      it 'exposes value and errors attributes' do
        result = described_class.new({ name: 'Alice' }, [{ field: :age, value: nil }])
        expect(result.value).to eq({ name: 'Alice' })
        expect(result.errors).to eq([{ field: :age, value: nil }])
      end

      it 'is valid when errors array is empty' do
        result = described_class.new({ name: 'Alice' }, [])
        expect(result).to be_valid
      end

      it 'is invalid when errors array has entries' do
        result = described_class.new({}, [{ field: :name, value: nil }])
        expect(result).not_to be_valid
      end

      it 'defaults errors to empty array when omitted' do
        result = described_class.new({ ok: true })
        expect(result).to be_valid
        expect(result.errors).to eq([])
      end
    end

    describe Philiprehberger::DataMapper::FieldDefinition do
      it 'reports conditional? as true when if: is provided' do
        field = described_class.new(:name, if: ->(_) { true })
        expect(field).to be_conditional
      end

      it 'reports conditional? as false when if: is not provided' do
        field = described_class.new(:name)
        expect(field).not_to be_conditional
      end
    end
  end

  describe '#field_names' do
    it 'returns the targets for fields and computed fields' do
      mapping = described_class.define do
        field(:name, from: :Name)
        field(:email, from: :Email)
        computed(:upper) { |r| r[:Name].to_s.upcase }
      end
      expect(mapping.field_names).to eq(%i[name email upper])
    end
  end

  describe '#has_field?' do
    let(:mapping) do
      described_class.define do
        field(:name, from: :Name)
        computed(:upper) { |r| r[:Name].to_s.upcase }
      end
    end

    it 'returns true for declared regular fields' do
      expect(mapping.has_field?(:name)).to be(true)
    end

    it 'returns true for declared computed fields' do
      expect(mapping.has_field?(:upper)).to be(true)
    end

    it 'returns false for undeclared fields' do
      expect(mapping.has_field?(:missing)).to be(false)
    end

    it 'accepts strings and coerces to symbol' do
      expect(mapping.has_field?('name')).to be(true)
    end
  end

  describe '#to_proc / #call' do
    let(:mapping) do
      described_class.define do
        field(:name, from: :Name)
      end
    end

    it '#call is an alias for #map' do
      expect(mapping.call({ Name: 'Ada' })).to eq(mapping.map({ Name: 'Ada' }))
    end

    it '#to_proc returns a Proc that maps a single record' do
      proc = mapping.to_proc
      expect(proc).to be_a(Proc)
      expect(proc.call({ Name: 'Ada' })).to eq({ name: 'Ada' })
    end

    it 'plays nicely with the & operator for batch mapping' do
      rows = [{ Name: 'Ada' }, { Name: 'Lin' }]
      expect(rows.map(&mapping)).to eq([{ name: 'Ada' }, { name: 'Lin' }])
    end
  end
end
