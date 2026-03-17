# frozen_string_literal: true

module Philiprehberger
  module DataMapper
    module Reversible
      def reverse(hash)
        build_reverse_mapping(hash)
      end

      private

      def build_reverse_mapping(hash)
        @fields.each_with_object({}) do |field, result|
          next unless hash.key?(field.target)

          result[field.source] = hash[field.target]
        end
      end
    end
  end
end
