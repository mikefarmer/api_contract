# frozen_string_literal: true

module ApiContract
  module Types
    # Detects when ActiveModel's type cast produced a silent fallback value
    # rather than a genuine coercion. Used globally for all attributes—both
    # scalar and typed array elements.
    #
    # ActiveModel silently coerces invalid strings to default values (e.g.
    # +"a"+ becomes +0+ for integers). This validator catches those cases
    # so they can be surfaced as validation errors instead.
    #
    # @example
    #   StrictCoercionValidator.valid_cast?("42", 42, :integer)   # => true
    #   StrictCoercionValidator.valid_cast?("a", 0, :integer)     # => false
    module StrictCoercionValidator
      # Types where string-to-zero fallback can occur.
      NUMERIC_TYPES = %i[integer big_integer float decimal].freeze

      # Strings accepted as valid boolean input by ActiveModel.
      VALID_BOOLEAN_STRINGS = Set.new(
        %w[true false 1 0 t f T F TRUE FALSE yes no YES NO y n Y N]
      ).freeze

      # Types that never produce a silent fallback.
      PASSTHROUGH_TYPES = %i[string value immutable_string].freeze

      # Date/time types where invalid strings cast to +nil+.
      TEMPORAL_TYPES = %i[date datetime time].freeze

      class << self
        # Returns whether the cast from +raw+ to +cast_value+ represents
        # a genuine coercion for the given type, as opposed to a silent
        # fallback.
        #
        # Only validates +String+ inputs—non-string raw values always pass.
        #
        # @param raw [Object] the original pre-cast value
        # @param cast_value [Object] the value after ActiveModel casting
        # @param type_symbol [Symbol] the ActiveModel type name
        # @return [Boolean] +true+ if the cast is valid
        def valid_cast?(raw, cast_value, type_symbol)
          return true unless raw.is_a?(String)
          return true if PASSTHROUGH_TYPES.include?(type_symbol)

          valid_for_type_category?(raw, cast_value, type_symbol)
        end

        private

        # Dispatches validation to the appropriate type-specific method.
        #
        # @param raw [String] the original string value
        # @param cast_value [Object] the cast value
        # @param type_symbol [Symbol] the ActiveModel type name
        # @return [Boolean]
        def valid_for_type_category?(raw, cast_value, type_symbol)
          if NUMERIC_TYPES.include?(type_symbol)
            valid_numeric_cast?(raw, cast_value, type_symbol)
          elsif type_symbol == :boolean
            valid_boolean_cast?(raw)
          elsif TEMPORAL_TYPES.include?(type_symbol)
            valid_temporal_cast?(raw, cast_value)
          else
            true
          end
        end

        # Checks whether a numeric cast is genuine. A fallback produces
        # zero, so if the cast result is zero we verify the input actually
        # represents zero.
        #
        # @param raw [String] the original string value
        # @param cast_value [Object] the cast numeric value
        # @param type_symbol [Symbol] the numeric type
        # @return [Boolean]
        def valid_numeric_cast?(raw, cast_value, type_symbol)
          zero_value = type_symbol == :decimal ? BigDecimal('0') : zero_for(type_symbol)
          return true unless cast_value == zero_value

          raw.match?(/\A\s*[+-]?0+(?:\.0*)?\s*\z/)
        end

        # Returns the zero value for a given numeric type.
        #
        # @param type_symbol [Symbol]
        # @return [Integer, Float]
        def zero_for(type_symbol)
          case type_symbol
          when :float then 0.0
          else 0
          end
        end

        # Checks whether the raw string is a recognized boolean value.
        #
        # @param raw [String] the original string value
        # @return [Boolean]
        def valid_boolean_cast?(raw)
          VALID_BOOLEAN_STRINGS.include?(raw)
        end

        # Checks whether a temporal cast is genuine. Invalid strings cast
        # to +nil+, so a non-empty string producing +nil+ is a fallback.
        #
        # @param raw [String] the original string value
        # @param cast_value [Object] the cast temporal value
        # @return [Boolean]
        def valid_temporal_cast?(raw, cast_value)
          return true unless cast_value.nil?

          raw.strip.empty?
        end
      end
    end
  end
end
