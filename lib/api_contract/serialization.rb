# frozen_string_literal: true

module ApiContract
  # Serialization and traversal methods for contracts. Provides +to_h+,
  # +as_json+, +to_json+, +as_camelcase_json+, +attributes+, +values+,
  # and +dig+.
  #
  # Included automatically by {ApiContract::Base}.
  module Serialization
    # Returns an array of declared attribute names as symbols, in
    # declaration order.
    #
    # @return [Array<Symbol>] declared attribute names
    #
    # @example
    #   contract.attributes # => [:name, :age, :email]
    def attributes
      self.class.declared_attribute_names.reject do |name|
        self.class.attribute_registry[name][:type] == :computed
      end
    end

    # Returns an array of attribute values in declaration order.
    #
    # @return [Array<Object>] attribute values
    #
    # @example
    #   contract.values # => ["Bob", 25, "bob@example.com"]
    def values
      attributes.map { |name| public_send(name) }
    end

    # Returns a symbolized hash of all declared attributes and their values.
    # Optional attributes with nil values are excluded.
    #
    # @return [Hash{Symbol => Object}] symbolized attribute hash
    #
    # @example
    #   contract.to_h # => { name: "Bob", age: 25 }
    def to_h
      attributes.each_with_object({}) do |name, hash|
        value = public_send(name)
        meta = self.class.attribute_registry[name]
        next if meta[:optional] && value.nil?

        hash[name] = value
      end
    end

    # Returns a string-keyed hash of all declared attributes.
    # Raises {InvalidContractError} if the contract is not valid.
    #
    # @return [Hash{String => Object}] string-keyed attribute hash
    # @raise [ApiContract::InvalidContractError] if the contract is invalid
    #
    # @example
    #   contract.as_json # => { "name" => "Bob", "age" => 25 }
    def as_json(_options = nil)
      validate_for_serialization!
      to_h.transform_keys(&:to_s)
    end

    # Returns a JSON string representation of the contract.
    # Raises {InvalidContractError} if the contract is not valid.
    #
    # @return [String] JSON string
    # @raise [ApiContract::InvalidContractError] if the contract is invalid
    #
    # @example
    #   contract.to_json # => '{"name":"Bob","age":25}'
    def to_json(*_args)
      JSON.generate(as_json)
    end

    # Returns a string-keyed hash with camelCase keys.
    # Raises {InvalidContractError} if the contract is not valid.
    #
    # @return [Hash{String => Object}] camelCase string-keyed hash
    # @raise [ApiContract::InvalidContractError] if the contract is invalid
    #
    # @example
    #   contract.as_camelcase_json # => { "homeAddress" => "..." }
    def as_camelcase_json
      validate_for_serialization!
      to_h.transform_keys { |key| camelize_key(key) }
    end

    # Delegates to +to_h.dig+ for nested value access.
    #
    # @param keys [Array<Symbol, Integer>] the keys to dig through
    # @return [Object, nil] the value at the nested key path
    #
    # @example
    #   contract.dig(:home_address, :street) # => "123 Main St"
    def dig(*keys)
      to_h.dig(*keys)
    end

    private

    # Validates that the contract is ready for serialization. Checks both
    # schema validity and data validity, raising {InvalidContractError}
    # if either check fails.
    #
    # @return [void]
    # @raise [ApiContract::InvalidContractError] if the contract is invalid
    def validate_for_serialization!
      raise_serialization_error!(schema_error_messages) unless schema_valid?
      raise_serialization_error!(data_error_messages) unless valid?
    end

    # Builds error messages from schema errors.
    #
    # @return [Array<String>] formatted error messages
    def schema_error_messages
      schema_errors.flat_map { |attr, errs| errs.map { |e| "#{attr} #{e}" } }
    end

    # Builds error messages from data validation errors.
    #
    # @return [Array<String>] formatted error messages
    def data_error_messages
      errors.map { |error| "#{error.attribute} #{error.message}" }
    end

    # Raises an {InvalidContractError} with the given messages.
    #
    # @param messages [Array<String>] the error messages
    # @raise [ApiContract::InvalidContractError]
    def raise_serialization_error!(messages)
      raise InvalidContractError.new(
        "Contract validation failed: #{messages.join(', ')}",
        contract: self
      )
    end

    # Converts a snake_case symbol to a camelCase string.
    #
    # @param key [Symbol] the snake_case key
    # @return [String] the camelCase string
    def camelize_key(key)
      key.to_s.gsub(/_([a-z\d])/) { ::Regexp.last_match(1).upcase }
    end
  end
end
