# frozen_string_literal: true

module ApiContract
  # Schema validation methods for contracts. Checks structural validity:
  # required attributes are present, no unexpected attributes exist.
  #
  # Included automatically by {ApiContract::Base}.
  module SchemaValidation
    # Returns a hash of schema errors. Keys are attribute names, values
    # are arrays of error message strings.
    #
    # @return [Hash{Symbol => Array<String>}] schema error messages
    def schema_errors
      errors_hash = {}
      missing_attribute_names.each { |name| errors_hash[name] = ['is missing'] }
      unexpected_attributes.each_key { |name| errors_hash[name] = ['is unexpected'] }
      errors_hash
    end

    # Returns whether the contract's structure is valid (all required keys
    # present, no unexpected keys).
    #
    # @return [Boolean] true if the schema is valid
    def schema_valid?
      schema_errors.empty?
    end

    # Validates the contract's structure, raising an exception if invalid.
    # Missing attributes are checked before unexpected attributes. Also
    # recurses into nested contracts.
    #
    # @return [void]
    # @raise [ApiContract::MissingAttributeError] if required attributes are absent
    # @raise [ApiContract::UnexpectedAttributeError] if unexpected attributes are present
    def schema_validate!
      validate_no_missing_attributes!
      validate_no_unexpected_attributes!
      validate_nested_schemas!
      nil
    end

    private

    # Returns the names of required attributes that were not provided.
    #
    # @return [Array<Symbol>] missing required attribute names
    def missing_attribute_names
      self.class.required_attribute_names.reject { |name| provided_keys.include?(name) }
    end

    # Raises {MissingAttributeError} if any required attributes are missing.
    #
    # @return [void]
    # @raise [ApiContract::MissingAttributeError]
    def validate_no_missing_attributes!
      missing = missing_attribute_names
      return if missing.empty?

      raise MissingAttributeError.new(
        "Missing required attribute(s): #{missing.join(', ')}",
        attributes: missing
      )
    end

    # Raises {UnexpectedAttributeError} if any unexpected attributes are present.
    #
    # @return [void]
    # @raise [ApiContract::UnexpectedAttributeError]
    def validate_no_unexpected_attributes!
      return if unexpected_attributes.empty?

      unexpected = unexpected_attributes.keys
      raise UnexpectedAttributeError.new(
        "Unexpected attribute(s): #{unexpected.join(', ')}",
        attributes: unexpected
      )
    end
  end
end
