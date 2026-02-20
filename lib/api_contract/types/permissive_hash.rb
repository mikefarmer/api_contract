# frozen_string_literal: true

module ApiContract
  module Types
    # An untyped hash type that accepts any keys and values without
    # element-level validation or coercion. Keys are deep-symbolized on cast.
    # Used via +attribute :foo, :permissive_hash+ in attribute declarations.
    #
    # @example
    #   class MyContract < ApiContract::Base
    #     attribute :metadata, :permissive_hash
    #   end
    #
    #   contract = MyContract.new(metadata: { "a" => 1, "b" => { "c" => 2 } })
    #   contract.metadata # => { a: 1, b: { c: 2 } }
    class PermissiveHash < ActiveModel::Type::Value
      # Casts the input to a hash with symbolized keys. Returns +nil+ for
      # +nil+, deep-symbolizes hashes, and passes through non-hash values
      # unchanged so that strict coercion validation can reject them.
      #
      # @param value [Object] the input value
      # @return [Hash, nil, Object] the cast hash, nil, or the original value
      def cast(value)
        return nil if value.nil?
        return deep_symbolize_keys(value) if value.is_a?(Hash)

        value
      end

      # Returns the type name used for registration and metadata.
      #
      # @return [Symbol]
      def type
        :permissive_hash
      end

      private

      # Recursively symbolizes all keys in a hash.
      #
      # @param hash [Hash] the hash to symbolize
      # @return [Hash] a new hash with all keys symbolized
      def deep_symbolize_keys(hash)
        hash.each_with_object({}) do |(key, val), result|
          sym_key = key.respond_to?(:to_sym) ? key.to_sym : key
          result[sym_key] = val.is_a?(Hash) ? deep_symbolize_keys(val) : val
        end
      end
    end
  end
end

ActiveModel::Type.register(:permissive_hash, ApiContract::Types::PermissiveHash)
