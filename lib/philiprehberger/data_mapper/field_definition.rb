# frozen_string_literal: true

module Philiprehberger
  module DataMapper
    class FieldDefinition
      attr_reader :target, :source, :default, :type, :condition, :validator, :split_delimiter

      BOOLEAN_TRUE_VALUES = %w[true 1 yes].freeze
      BOOLEAN_FALSE_VALUES = %w[false 0 no].freeze

      def initialize(target, **opts, &transform)
        @target = target
        @source = opts[:from] || target
        @default = opts[:default]
        @type = opts[:type]
        @condition = opts[:if]
        @validator = opts[:validate]
        @split_delimiter = opts[:split]
        @transform = transform
      end

      def apply(value)
        value = @default if value.nil?
        value = value.to_s.split(@split_delimiter) if @split_delimiter && value.is_a?(String)
        value = @transform.call(value) if @transform
        value = coerce(value) if @type
        value
      end

      def conditional?
        !@condition.nil?
      end

      def include?(record)
        return true unless conditional?

        @condition.call(record)
      end

      def valid?(value)
        return true unless @validator

        @validator.call(value)
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
        return value if [true, false].include?(value)

        str = value.to_s.downcase
        return true if BOOLEAN_TRUE_VALUES.include?(str)
        return false if BOOLEAN_FALSE_VALUES.include?(str)

        value
      end
    end
  end
end
