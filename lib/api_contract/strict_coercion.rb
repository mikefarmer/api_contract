# frozen_string_literal: true

module ApiContract
  # Mixin that validates attribute casts were genuine coercions, not
  # silent ActiveModel fallbacks. Included by {ApiContract::Base}.
  #
  # Captures raw (pre-cast) attribute values during initialization and
  # adds an ActiveModel validation callback that checks each attribute
  # for fallback casts.
  module StrictCoercion
    # Sets up the validation callback when included.
    #
    # @param base [Class] the including class
    # @return [void]
    def self.included(base)
      base.validate :validate_strict_coercion
    end

    private

    # Captures raw attribute values before ActiveModel casting.
    #
    # @param known [Hash] the known attribute hash
    # @return [void]
    def capture_raw_attributes(known)
      @_raw_attributes = known.dup.freeze
    end

    # Validates that all attribute casts were genuine coercions, not
    # silent fallbacks.
    #
    # @return [void]
    def validate_strict_coercion
      self.class.attribute_registry.each do |attr_name, meta|
        next unless @_raw_attributes.key?(attr_name)

        validate_attribute_coercion(attr_name, meta)
      end
    end

    # Dispatches coercion validation for a single attribute.
    #
    # @param attr_name [Symbol] the attribute name
    # @param meta [Hash] the attribute metadata
    # @return [void]
    def validate_attribute_coercion(attr_name, meta)
      raw = @_raw_attributes[attr_name]
      cast = public_send(attr_name)

      if meta[:type] == :array && meta[:element_type] && meta[:element_type] != :permissive
        validate_typed_array_coercion(attr_name, raw, cast, meta[:element_type])
      elsif meta[:type] != :array
        validate_scalar_coercion(attr_name, raw, cast, meta[:type])
      end
    end

    # Validates each element of a typed array for fallback casts.
    #
    # @param attr_name [Symbol] the attribute name
    # @param raw [Object] the raw pre-cast value
    # @param cast [Array, nil] the cast array
    # @param element_type [Symbol] the element type symbol
    # @return [void]
    def validate_typed_array_coercion(attr_name, raw, cast, element_type)
      return unless raw.is_a?(Array) && cast.is_a?(Array)

      raw.each_with_index do |raw_element, index|
        cast_element = cast[index]
        next if Types::StrictCoercionValidator.valid_cast?(raw_element, cast_element, element_type)

        errors.add(attr_name, "element at index #{index} is not a valid #{element_type}: #{raw_element.inspect}")
      end
    end

    # Validates a scalar attribute for fallback casts.
    #
    # @param attr_name [Symbol] the attribute name
    # @param raw [Object] the raw pre-cast value
    # @param cast [Object] the cast value
    # @param type_sym [Symbol] the type symbol
    # @return [void]
    def validate_scalar_coercion(attr_name, raw, cast, type_sym)
      return if Types::StrictCoercionValidator.valid_cast?(raw, cast, type_sym)

      errors.add(attr_name, "is not a valid #{type_sym}: #{raw.inspect}")
    end
  end
end
