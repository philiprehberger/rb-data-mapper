# frozen_string_literal: true

module Philiprehberger
  module DataMapper
    class FieldDefinition
      attr_reader :target, :source, :default

      def initialize(target, from: nil, default: nil, &transform)
        @target = target
        @source = from || target
        @default = default
        @transform = transform
      end

      def apply(value)
        value = @default if value.nil?
        @transform ? @transform.call(value) : value
      end
    end
  end
end
