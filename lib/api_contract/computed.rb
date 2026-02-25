# frozen_string_literal: true

module ApiContract
  # Support for computed attributes — derived values produced at
  # serialization time. Computed attributes are excluded from
  # deserialization, schema validation, and the +attributes+ list.
  # They are included in serialization output (+to_h+, +as_json+, etc.).
  #
  # Included automatically by {ApiContract::Base}.
  #
  # @example
  #   attribute :coordinates, :computed, with: -> { [latitude, longitude] }
  #   attribute :full_name, :computed, :build_full_name
  module Computed
    # Sets up class-level computed attribute tracking when included.
    #
    # @param base [Class] the including class
    # @return [void]
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level methods for declaring computed attributes.
    module ClassMethods
      # Returns the names of all computed attributes.
      #
      # @return [Array<Symbol>] computed attribute names
      def computed_attribute_names
        attribute_registry.each_with_object([]) do |(name, meta), arr|
          arr << name if meta[:type] == :computed
        end
      end
    end

    # Overrides +to_h+ to include computed attribute values.
    #
    # @return [Hash{Symbol => Object}] symbolized attribute hash with computed values
    def to_h
      result = super
      append_computed_values(result)
      result
    end

    private

    # Appends computed attribute values to the given hash.
    #
    # @param hash [Hash] the hash to append to
    # @return [void]
    def append_computed_values(hash)
      self.class.computed_attribute_names.each do |name|
        meta = self.class.attribute_registry[name]
        hash[name] = evaluate_computed(meta)
      end
    end

    # Evaluates a computed attribute's value using its +with+ option.
    #
    # @param meta [Hash] the attribute metadata
    # @return [Object] the computed value
    def evaluate_computed(meta)
      with = meta[:with]
      if with.is_a?(Proc)
        instance_exec(&with)
      elsif with.is_a?(Symbol)
        send(with)
      end
    end
  end
end
