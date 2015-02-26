# frozen_string_literal: true

module Philiprehberger
  module DataMapper
    class FieldDefinition
      attr_reader :target, :source, :default, :type

      BOOLEAN_TRUE_VALUES = %w[true 1 yes].freeze
      BOOLEAN_FALSE_VALUES = %w[false 0 no].freeze

      def initialize(target, from: nil, default: nil, type: nil, &transform)
        @target = target
        @source = from || target
        @default = default
        @type = type
        @transform = transform
      end

      def apply(value)
        value = @default if value.nil?
        value = @transform.call(value) if @transform
        value = coerce(value) if @type
        value
      end

      private

      def coerce(value)
        return value if value.nil?

        case @type
        when :string  then value.to_s
        when :integer then Integer(value)
        when :float   then Float(value)
        when :boolean then coerce_boolean(value)
        else value
        end
      end

      def coerce_boolean(value)
        return value if value == true || value == false

        str = value.to_s.downcase
        return true if BOOLEAN_TRUE_VALUES.include?(str)
        return false if BOOLEAN_FALSE_VALUES.include?(str)

        value
      end
    end
  end
end
