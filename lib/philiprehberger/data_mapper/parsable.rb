# frozen_string_literal: true

require "csv"
require "json"

module Philiprehberger
  module DataMapper
    module Parsable
      def from_csv(csv_string, headers: true)
        rows = CSV.parse(csv_string, headers: headers)
        rows.map { |row| map(row_to_hash(row)) }
      end

      def from_json(json_string)
        parsed = JSON.parse(json_string)

        case parsed
        when Array then map_all(parsed.map { |h| symbolize_keys(h) })
        when Hash  then map(symbolize_keys(parsed))
        end
      end

      private

      def symbolize_keys(hash)
        hash.each_with_object({}) do |(key, value), result|
          result[key.to_sym] = value.is_a?(Hash) ? symbolize_keys(value) : value
        end
      end

      def row_to_hash(row)
        row.to_h.transform_keys(&:to_sym)
      end
    end
  end
end
