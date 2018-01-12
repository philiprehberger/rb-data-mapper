# frozen_string_literal: true

require_relative "lib/philiprehberger/data_mapper/version"

Gem::Specification.new do |spec|
  spec.name          = "philiprehberger-data_mapper"
  spec.version       = Philiprehberger::DataMapper::VERSION
  spec.authors       = ["Philip Rehberger"]
  spec.email         = ["me@philiprehberger.com"]

  spec.summary       = "Data transformation DSL for mapping hashes and CSV rows"
  spec.description   = "A zero-dependency Ruby gem for transforming data between formats " \
                       "with a mapping DSL, field renaming, type conversion, validation, and CSV support."
  spec.homepage      = "https://github.com/philiprehberger/rb-data-mapper"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]
end
