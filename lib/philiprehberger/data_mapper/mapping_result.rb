# frozen_string_literal: true

module Philiprehberger
  module DataMapper
    class MappingResult
      attr_reader :value, :errors

      def initialize(value, errors = [])
        @value = value
        @errors = errors
      end

      def valid?
        @errors.empty?
      end
    end
  end
end
