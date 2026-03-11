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

      def field(target, from: nil, default: nil, &transform)
        @fields << FieldDefinition.new(target, from: from, default: default, &transform)
      end

      def map(hash)
        @fields.each_with_object({}) do |field, result|
          value = hash[field.source]
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

      private

      def row_to_hash(row)
        row.to_h.transform_keys(&:to_sym)
      end
    end
  end
end
