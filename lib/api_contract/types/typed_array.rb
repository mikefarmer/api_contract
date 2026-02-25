# frozen_string_literal: true

module ApiContract
  # Custom ActiveModel type classes for arrays, hashes, and coercion.
  module Types
    # A parameterized array type that casts each element using an
    # ActiveModel type. Instances are created per-attribute since each
    # may have a different element type.
    #
    # Casting does not raise on invalid elements—errors are deferred
    # to the validation callback in {ApiContract::Base}.
    #
    # @example
    #   typed = TypedArray.new(element_type: :integer)
    #   typed.cast(["1", "2", "3"]) # => [1, 2, 3]
    class TypedArray < ActiveModel::Type::Value
      # @return [Symbol] the element type symbol (e.g. +:integer+, +:string+)
      attr_reader :element_type_symbol

      # Creates a new typed array type for the given element type.
      #
      # @param element_type [Symbol] the ActiveModel type for elements
      def initialize(element_type:)
        @element_type_symbol = element_type
        @element_caster = ActiveModel::Type.lookup(element_type)
        super()
      end

      # Casts the input to an array, coercing each element with the
      # element type caster. Returns +nil+ for +nil+ and passes through
      # non-array values so that strict coercion validation can reject them.
      #
      # @param value [Object] the input value
      # @return [Array, nil, Object] the cast array, nil, or the original value
      def cast(value)
        return nil if value.nil?
        return value unless value.is_a?(Array)

        value.map { |element| @element_caster.cast(element) }
      end

      # Returns the type name for metadata.
      #
      # @return [Symbol]
      def type
        :array
      end
    end
  end
end
