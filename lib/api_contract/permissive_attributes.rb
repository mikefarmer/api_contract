# frozen_string_literal: true

module ApiContract
  # Mixin for contracts that need to accept and round-trip unknown keys
  # alongside their declared schema. Including this module disables strict
  # deserialization — +from_params+ and +from_json+ will no longer raise
  # +UnexpectedAttributeError+ for unknown keys.
  #
  # Unknown keys are stored separately and are invisible in serialization
  # by default. Use +permissive: true+ or +with_passthrough_attributes+
  # to include them.
  #
  # @example
  #   class FlexContract < ApiContract::Base
  #     include ApiContract::PermissiveAttributes
  #     attribute :name, :string
  #   end
  module PermissiveAttributes
    # Returns whether this contract accepts permissive attributes.
    #
    # @return [Boolean] always true when the module is included
    def permissive?
      true
    end

    # Checks whether a key exists in either declared or permissive attributes.
    #
    # @param key [Symbol, String] the key to check
    # @return [Boolean] true if the key exists anywhere
    def key?(key)
      key = key.to_sym
      self.class.declared_attribute_names.include?(key) || unexpected_attributes.key?(key)
    end

    alias has_key? key?

    # Checks whether a key is a declared attribute (part of the schema).
    #
    # @param key [Symbol, String] the key to check
    # @return [Boolean] true if the key is a declared attribute
    def declared_attribute?(key)
      self.class.declared_attribute_names.include?(key.to_sym)
    end

    alias has_attribute? declared_attribute?

    # Returns the hash of unknown keys/values stored separately.
    #
    # @return [Hash{Symbol => Object}] permissive attribute names and values
    def permissive_attributes
      unexpected_attributes
    end

    # Returns a wrapper that includes permissive attributes in +to_h+.
    #
    # @return [PassthroughWrapper] a wrapper with permissive attributes
    def with_passthrough_attributes
      PassthroughWrapper.new(self)
    end

    # Overrides +as_json+ to optionally include permissive attributes.
    #
    # @param options [Hash, nil] options hash
    # @option options [Boolean] :permissive include permissive attributes
    # @return [Hash{String => Object}] string-keyed hash
    # @raise [ApiContract::InvalidContractError] if the contract is invalid
    def as_json(options = nil)
      result = super
      permissive_attributes.each { |k, v| result[k.to_s] = v } if options.is_a?(Hash) && options[:permissive]
      result
    end

    # Overrides +schema_errors+ to exclude unexpected attribute errors
    # since permissive contracts accept unknown keys.
    #
    # @return [Hash{Symbol => Array<String>}] schema error messages
    def schema_errors
      errors_hash = {}
      missing_attribute_names.each { |name| errors_hash[name] = ['is missing'] }
      errors_hash
    end

    # Overrides schema validation to skip unexpected attribute checks
    # when the module is included.
    #
    # @return [void]
    def schema_validate!
      validate_no_missing_attributes!
      validate_nested_schemas!
      nil
    end

    # Thin wrapper that includes permissive attributes in +to_h+.
    class PassthroughWrapper
      # @param contract [ApiContract::Base] the wrapped contract
      def initialize(contract)
        @contract = contract
      end

      # Returns a hash including both declared and permissive attributes.
      #
      # @return [Hash{Symbol => Object}] merged attribute hash
      def to_h
        @contract.to_h.merge(@contract.permissive_attributes)
      end
    end
  end
end
