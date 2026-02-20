# frozen_string_literal: true

module ApiContract
  module Types
    # An untyped array type that accepts any elements without validation
    # or coercion. Used via +array: :permissive+ in attribute declarations.
    #
    # @example
    #   class MyContract < ApiContract::Base
    #     attribute :items, array: :permissive
    #   end
    #
    #   contract = MyContract.new(items: [1, "two", nil, { x: 3 }])
    #   contract.items # => [1, "two", nil, { x: 3 }]
    class PermissiveArray < ActiveModel::Type::Value
      # Casts the input to an array. Returns +nil+ for +nil+, passes
      # through arrays unchanged, and wraps other values using +Array()+.
      #
      # @param value [Object] the input value
      # @return [Array, nil] the cast array or nil
      def cast(value)
        return nil if value.nil?
        return value if value.is_a?(Array)

        Array(value)
      end

      # Returns the type name used for registration and metadata.
      #
      # @return [Symbol]
      def type
        :permissive_array
      end
    end
  end
end
