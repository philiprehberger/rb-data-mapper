# frozen_string_literal: true

require_relative 'parsable'
require_relative 'reversible'

module Philiprehberger
  module DataMapper
    class Mapping
      include Parsable
      include Reversible

      def initialize(&block)
        @fields = []
        @computed_fields = []
        instance_eval(&block) if block
      end

      def field(target, ...)
        @fields << FieldDefinition.new(target, ...)
      end

      def computed(target, &)
        @computed_fields << ComputedDefinition.new(target, &)
      end

      def array_field(target, split: ',', **opts, &transform)
        field(target, split: split, **opts, &transform)
      end

      def map(hash)
        result = map_fields(hash)
        apply_computed(hash, result)
        result
      end

      def map_with_validation(hash)
        result = {}
        errors = collect_errors(hash, result)
        apply_computed(hash, result)
        MappingResult.new(result, errors)
      end

      def map_all(array)
        array.map { |hash| map(hash) }
      end

      def map_lazy(enumerable)
        enumerable.lazy.map { |hash| map(hash) }
      end

      # Names (targets) of every declared field, including computed fields.
      #
      # @return [Array<Symbol>]
      def field_names
        @fields.map(&:target) + @computed_fields.map(&:target)
      end

      private

      def map_fields(hash)
        applicable_fields(hash).each_with_object({}) do |f, result|
          value = dig_value(hash, f.source)
          result[f.target] = f.apply(value)
        end
      end

      def collect_errors(hash, result)
        errors = []
        applicable_fields(hash).each do |f|
          value = dig_value(hash, f.source)
          mapped = f.apply(value)
          errors << { field: f.target, value: mapped } unless f.valid?(mapped)
          result[f.target] = mapped
        end
        errors
      end

      def applicable_fields(hash)
        @fields.select { |f| f.include?(hash) }
      end

      def apply_computed(hash, result)
        @computed_fields.each do |c|
          result[c.target] = c.compute(hash)
        end
      end

      def dig_value(hash, source)
        key_str = source.to_s
        return hash[source] if hash.key?(source)
        return hash[key_str] if hash.key?(key_str)
        return unless key_str.include?('.')

        dig_nested(hash, key_str.split('.'))
      end

      def dig_nested(hash, keys)
        keys.reduce(hash) do |current, key|
          break nil unless current.is_a?(Hash)

          current[key.to_sym] || current[key]
        end
      end
    end
  end
end
