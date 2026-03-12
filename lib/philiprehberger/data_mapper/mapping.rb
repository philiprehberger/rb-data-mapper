# frozen_string_literal: true

require "csv"
require "json"

module Philiprehberger
  module DataMapper
    class Mapping
      def initialize(&block)
        @fields = []
        instance_eval(&block) if block
      end

      def field(target, from: nil, default: nil, type: nil, &transform)
        @fields << FieldDefinition.new(target, from: from, default: default, type: type, &transform)
      end

      def map(hash)
        @fields.each_with_object({}) do |field, result|
          value = dig_value(hash, field.source)
          result[field.target] = field.apply(value)
        end
      end

      def map_all(array)
        array.map { |hash| map(hash) }
      end

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

      def dig_value(hash, source)
        key_str = source.to_s
        return hash[source] if hash.key?(source)
        return hash[key_str] if hash.key?(key_str)

        if key_str.include?(".")
          keys = key_str.split(".")
          keys.reduce(hash) do |current, key|
            break nil if current.nil?

            if current.is_a?(Hash)
              current[key.to_sym] || current[key]
            end
          end
        end
      end

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
