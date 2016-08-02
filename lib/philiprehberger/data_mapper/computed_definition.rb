# frozen_string_literal: true

module Philiprehberger
  module DataMapper
    class ComputedDefinition
      attr_reader :target

      def initialize(target, &block)
        @target = target
        @block = block
      end

      def compute(record)
        @block.call(record)
      end
    end
  end
end
