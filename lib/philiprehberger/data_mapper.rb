# frozen_string_literal: true

require_relative "data_mapper/version"
require_relative "data_mapper/field_definition"
require_relative "data_mapper/mapping"

module Philiprehberger
  module DataMapper
    def self.define(&)
      Mapping.new(&)
    end
  end
end
