# philiprehberger-data_mapper

[![Tests](https://github.com/philiprehberger/rb-data-mapper/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-data-mapper/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-data_mapper.svg)](https://rubygems.org/gems/philiprehberger-data_mapper)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-data-mapper)](https://github.com/philiprehberger/rb-data-mapper/commits/main)

Data transformation DSL for mapping hashes and CSV rows

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-data_mapper"
```

Or install directly:

```bash
gem install philiprehberger-data_mapper
```

## Usage

```ruby
require "philiprehberger/data_mapper"

mapping = Philiprehberger::DataMapper.define do
  field :full_name, from: :name
  field :years, from: :age, &:to_i
  field :role, default: "member"
end
```

### Map a single hash

```ruby
input = { name: "Alice", age: "30" }
mapping.map(input)
# => { full_name: "Alice", years: 30, role: "member" }
```

### Map an array of hashes

```ruby
input = [
  { name: "Alice", age: "30" },
  { name: "Bob", age: "25" }
]
mapping.map_all(input)
# => [{ full_name: "Alice", years: 30, role: "member" }, ...]
```

### Lazy streaming

Use `map_lazy` to pipe huge datasets without materializing an intermediate array. It returns an `Enumerator::Lazy` that applies `#map` per-element, so it composes with `.first`, `.select`, `.reject`, and works on infinite enumerables:

```ruby
mapping = Philiprehberger::DataMapper.define do
  field :id
end

infinite = (1..).lazy.map { |i| { "id" => i } }
mapping.map_lazy(infinite).first(3)
# => [{ id: 1 }, { id: 2 }, { id: 3 }]
```

### Use as a callable

`Mapping#call` is an alias for `#map`, and `Mapping#to_proc` returns a proc, so a mapping can be passed wherever a callable is expected:

```ruby
mapping = Philiprehberger::DataMapper.define do
  field :name, from: :Name
end

mapping.call({ Name: "Ada" })      # => { name: "Ada" }
[{ Name: "Ada" }, { Name: "Lin" }].map(&mapping)
# => [{ name: "Ada" }, { name: "Lin" }]
```

### Parse CSV

```ruby
csv = "name,age\nAlice,30\nBob,25\n"
mapping.from_csv(csv)
# => [{ full_name: "Alice", years: 30, role: "member" }, ...]
```

### Transform blocks

```ruby
mapping = Philiprehberger::DataMapper.define do
  field :email, from: :raw_email, &:downcase
  field :tags, from: :tag_string do |val|
    val.split(",").map(&:strip)
  end
end
```

### Nested key access

Use dot-notation in `from:` to access nested hash keys:

```ruby
mapping = Philiprehberger::DataMapper.define do
  field :city, from: "address.city"
  field :zip, from: "address.zip"
end

input = { address: { city: "Vienna", zip: "1010" } }
mapping.map(input)
# => { city: "Vienna", zip: "1010" }
```

### Type coercion

Use the `type:` parameter to automatically coerce values:

```ruby
mapping = Philiprehberger::DataMapper.define do
  field :name, from: :raw_name, type: :string
  field :age, from: :raw_age, type: :integer
  field :score, from: :raw_score, type: :float
  field :active, from: :raw_active, type: :boolean
end

input = { raw_name: 123, raw_age: "30", raw_score: "9.5", raw_active: "true" }
mapping.map(input)
# => { name: "123", age: 30, score: 9.5, active: true }
```

Supported types: `:string`, `:integer`, `:float`, `:boolean`.

### Conditional mapping

Include a field only when a condition is met using the `if:` parameter:

```ruby
mapping = Philiprehberger::DataMapper.define do
  field :name
  field :role, from: :raw_role, if: ->(record) { record[:admin] }
end

mapping.map({ name: "Alice", raw_role: "superuser", admin: true })
# => { name: "Alice", role: "superuser" }

mapping.map({ name: "Bob", raw_role: "superuser", admin: false })
# => { name: "Bob" }
```

### Computed fields

Derive fields from the full source record using `computed`:

```ruby
mapping = Philiprehberger::DataMapper.define do
  field :email
  computed(:full_name) { |record| "#{record[:first]} #{record[:last]}" }
  computed(:initials) { |record| "#{record[:first][0]}#{record[:last][0]}" }
end

mapping.map({ email: "a@b.com", first: "Alice", last: "Smith" })
# => { email: "a@b.com", full_name: "Alice Smith", initials: "AS" }
```

### Collection mapping

Split a single string value into an array using `array_field`:

```ruby
mapping = Philiprehberger::DataMapper.define do
  array_field :tags, from: :tag_csv, split: ","
  array_field :items, from: :item_str, split: "|"
end

mapping.map({ tag_csv: "ruby,rails,gem", item_str: "one|two|three" })
# => { tags: ["ruby", "rails", "gem"], items: ["one", "two", "three"] }
```

### Reverse mapping

Transform output back to the input schema using inverse field mappings:

```ruby
mapping = Philiprehberger::DataMapper.define do
  field :full_name, from: :name
  field :years, from: :age
end

output = { full_name: "Alice", years: 30 }
mapping.reverse(output)
# => { name: "Alice", age: 30 }
```

### Introspection

```ruby
mapping = Philiprehberger::DataMapper.define do
  field(:name, from: :Name)
  computed(:upper) { |r| r[:Name].upcase }
end
mapping.field_names  # => [:name, :upper]
```

### Validation

Validate mapped values using the `validate:` parameter. Use `map_with_validation` to collect errors:

```ruby
mapping = Philiprehberger::DataMapper.define do
  field :age, from: :raw_age, type: :integer, validate: ->(v) { v > 0 }
  field :name, validate: ->(v) { !v.nil? && !v.empty? }
end

result = mapping.map_with_validation({ raw_age: "25", name: "Alice" })
result.valid?  # => true
result.value   # => { age: 25, name: "Alice" }
result.errors  # => []

result = mapping.map_with_validation({ raw_age: "-1", name: "" })
result.valid?  # => false
result.value   # => { age: -1, name: "" }
result.errors  # => [{ field: :age, value: -1 }, { field: :name, value: "" }]
```

## API

| Method | Description |
|--------|-------------|
| `DataMapper.define(&block)` | Create a new mapping with the DSL |
| `Mapping#field(target, from:, default:, type:, if:, validate:, split:, &transform)` | Define a field mapping |
| `Mapping#computed(target, &block)` | Define a computed field derived from the full record |
| `Mapping#array_field(target, from:, split:, &transform)` | Define a field that splits a string into an array |
| `Mapping#map(hash)` | Apply mapping to a single hash |
| `Mapping#call(hash)` | Alias for `#map` — lets a `Mapping` be used as a callable |
| `Mapping#to_proc` | Return a `Proc` that calls `#map`, usable with `array.map(&mapping)` |
| `Mapping#map_with_validation(hash)` | Apply mapping and return a `MappingResult` with errors |
| `Mapping#map_all(array)` | Apply mapping to an array of hashes |
| `Mapping#map_lazy(enumerable)` | Return a `Lazy` Enumerator applying `#map` per-element for streaming |
| `Mapping#field_names` | Array of symbol targets for declared fields and computed fields |
| `Mapping#reverse(hash)` | Transform output hash back to input schema |
| `Mapping#from_csv(string, headers: true)` | Parse CSV and map each row |
| `Mapping#from_json(json_string)` | Parse JSON string and map the result |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-data-mapper)

🐛 [Report issues](https://github.com/philiprehberger/rb-data-mapper/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-data-mapper/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
