# philiprehberger-data_mapper

[![Tests](https://github.com/philiprehberger/rb-data-mapper/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-data-mapper/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-data_mapper.svg)](https://rubygems.org/gems/philiprehberger-data_mapper)

Data transformation DSL for mapping hashes and CSV rows in Ruby.

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-data_mapper"
```

Then run:

```bash
bundle install
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

## API

| Method | Description |
|--------|-------------|
| `DataMapper.define(&block)` | Create a new mapping with the DSL |
| `Mapping#field(target, from:, default:, &transform)` | Define a field mapping |
| `Mapping#map(hash)` | Apply mapping to a single hash |
| `Mapping#map_all(array)` | Apply mapping to an array of hashes |
| `Mapping#from_csv(string, headers: true)` | Parse CSV and map each row |

## Development

```bash
bundle install
bundle exec rspec      # Run tests
bundle exec rubocop    # Check code style
```

## License

MIT
