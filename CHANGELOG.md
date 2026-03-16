# Changelog

## 0.2.1

- Add License badge to README
- Add bug_tracker_uri to gemspec

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-03-12

### Added
- Nested key access via dot-notation in `from:` (e.g., `from: "address.city"`)
- Built-in type coercion with `type:` parameter (`:string`, `:integer`, `:float`, `:boolean`)
- `from_json` method for parsing and mapping JSON strings

## [0.1.0] - 2026-03-10

### Added
- Initial release
- DSL for defining field mappings with `field` method
- Field renaming via `from:` option
- Default values for missing fields
- Transform blocks for value conversion
- `map` for single hash transformation
- `map_all` for batch hash transformation
- `from_csv` for CSV string parsing and mapping
