# frozen_string_literal: true

module ApiContract
  # Rails interop methods for contracts. Provides +from_camelized_json+
  # for deserializing camelCase JSON and +to_params+ for converting
  # contracts to +ActionController::Parameters+.
  #
  # Included automatically by {ApiContract::Base}.
  module RailsInterop
    # Sets up class-level methods when included.
    #
    # @param base [Class] the including class
    # @return [void]
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level methods for camelCase JSON deserialization.
    module ClassMethods
      # Constructs a contract from a camelCase JSON string. Keys are
      # converted from camelCase to snake_case before deserialization.
      #
      # @param json [String] a JSON string with camelCase keys
      # @return [ApiContract::Base] a validated contract instance
      # @raise [JSON::ParserError] if the JSON string is malformed
      # @raise [ApiContract::MissingAttributeError] if required attributes are absent
      # @raise [ApiContract::UnexpectedAttributeError] if unexpected attributes are present
      # @raise [ApiContract::InvalidContractError] if data validations fail
      def from_camelized_json(json)
        attrs = JSON.parse(json)
        snake_attrs = deep_underscore_keys(attrs)
        from_params(snake_attrs)
      end

      private

      # Recursively converts camelCase string keys to snake_case symbols.
      #
      # @param obj [Hash, Array, Object] the object to transform
      # @return [Hash, Array, Object] the transformed object
      def deep_underscore_keys(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(key, value), result|
            result[underscore_key(key)] = deep_underscore_keys(value)
          end
        when Array
          obj.map { |item| deep_underscore_keys(item) }
        else
          obj
        end
      end

      # Converts a camelCase string to a snake_case symbol.
      #
      # @param key [String, Symbol] the camelCase key
      # @return [Symbol] the snake_case symbol
      def underscore_key(key)
        key.to_s
           .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
           .downcase
           .to_sym
      end
    end

    # Returns an +ActionController::Parameters+ instance representing
    # this contract. Nested contracts become nested parameters. The
    # result is pre-permitted when the contract is schema-valid.
    #
    # @return [ActionController::Parameters] the contract as params
    # @raise [LoadError] if actionpack is not available
    def to_params
      require 'action_controller'
      hash = build_params_hash
      params = ActionController::Parameters.new(hash)
      params.permit! if schema_valid?
      params
    end

    private

    # Builds a string-keyed hash suitable for ActionController::Parameters,
    # recursively converting nested contracts.
    #
    # @return [Hash{String => Object}] string-keyed hash
    def build_params_hash
      to_h.each_with_object({}) do |(key, value), result|
        result[key.to_s] = convert_param_value(value)
      end
    end

    # Converts a single value for ActionController::Parameters.
    # Nested contracts become nested hashes, arrays are mapped.
    #
    # @param value [Object] the value to convert
    # @return [Object] the converted value
    def convert_param_value(value)
      case value
      when Hash
        value.transform_keys(&:to_s)
      when Array
        value.map { |item| convert_param_value(item) }
      else
        value
      end
    end
  end
end
