# frozen_string_literal: true

module ApiContract
  # Handles nested contract instantiation, resolution, validation, and
  # serialization. When an attribute is declared with +contract:+, hash
  # values are automatically instantiated as the referenced contract class.
  #
  # String references are resolved at runtime and memoized in a
  # thread-safe manner.
  #
  # Included automatically by {ApiContract::Base}.
  module NestedContract
    # Sets up class-level contract resolution when included.
    #
    # @param base [Class] the including class
    # @return [void]
    def self.included(base)
      base.extend(ClassMethods)
      base.validate :validate_nested_contracts
    end

    # Class-level methods for resolving contract references.
    module ClassMethods
      # Resolves a contract reference (Class or String) to a Class.
      # String references are memoized thread-safely.
      #
      # @param reference [Class, String] the contract class or string name
      # @return [Class] the resolved contract class
      def resolve_contract(reference)
        return reference if reference.is_a?(Class)

        contract_resolution_mutex.synchronize do
          resolved_contracts[reference] ||= Object.const_get(reference)
        end
      end

      private

      # @return [Mutex] mutex for thread-safe contract resolution
      def contract_resolution_mutex
        @contract_resolution_mutex ||= Mutex.new
      end

      # @return [Hash{String => Class}] cache of resolved contract classes
      def resolved_contracts
        @resolved_contracts ||= {}
      end

      # Inherits resolution caches on subclassing.
      #
      # @param subclass [Class] the new subclass
      # @return [void]
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@resolved_contracts, {})
        subclass.instance_variable_set(:@contract_resolution_mutex, Mutex.new)
      end
    end

    # Overrides +to_h+ to recursively serialize nested contracts.
    #
    # @return [Hash{Symbol => Object}] symbolized attribute hash
    def to_h
      super.transform_values { |v| v.is_a?(ApiContract::Base) ? v.to_h : v }
    end

    # Overrides +as_json+ to deep-convert keys to strings for nested
    # contracts.
    #
    # @return [Hash{String => Object}] string-keyed hash
    # @raise [ApiContract::InvalidContractError] if the contract is invalid
    def as_json(_options = nil)
      validate_for_serialization!
      deep_stringify_keys(to_h)
    end

    # Overrides +as_camelcase_json+ to deep-convert keys to camelCase
    # for nested contracts.
    #
    # @return [Hash{String => Object}] camelCase string-keyed hash
    # @raise [ApiContract::InvalidContractError] if the contract is invalid
    def as_camelcase_json
      validate_for_serialization!
      deep_camelize_keys(to_h)
    end

    private

    # Instantiates nested contracts from hash values during initialization.
    #
    # @return [void]
    def instantiate_nested_contracts!
      self.class.attribute_registry.each do |attr_name, meta|
        next unless meta[:contract]

        instantiate_nested_attribute(attr_name, meta)
      end
    end

    # Instantiates a single nested contract attribute if its value is a Hash.
    # Handles both direct contract references and {OneOf} descriptors.
    #
    # @param attr_name [Symbol] the attribute name
    # @param meta [Hash] the attribute metadata
    # @return [void]
    def instantiate_nested_attribute(attr_name, meta)
      value = public_send(attr_name)
      return unless value.is_a?(Hash)

      contract_ref = meta[:contract]
      nested = if contract_ref.is_a?(ApiContract::OneOf)
                 resolve_one_of(contract_ref, value, meta[:permissive])
               else
                 self.class.resolve_contract(contract_ref).new(value)
               end
      _write_attribute(attr_name.to_s, nested)
    end

    # Resolves a {OneOf} descriptor against a hash value.
    #
    # @param one_of [ApiContract::OneOf] the descriptor
    # @param value [Hash] the input hash
    # @param permissive [Boolean] whether to fall back to a plain hash
    # @return [ApiContract::Base, Hash] the resolved contract or plain hash
    # @raise [ApiContract::UnexpectedAttributeError] if no candidate matches and not permissive
    def resolve_one_of(one_of, value, permissive)
      result = one_of.resolve(value, resolver: self.class)
      return result if result

      return value if permissive

      raise UnexpectedAttributeError.new(
        "No matching contract for one_of: #{one_of.candidates.inspect}",
        attributes: value.keys
      )
    end

    # Validates schema of all nested contracts, raising on the first error.
    #
    # @return [void]
    # @raise [ApiContract::MissingAttributeError]
    # @raise [ApiContract::UnexpectedAttributeError]
    def validate_nested_schemas!
      self.class.attribute_registry.each do |attr_name, meta|
        next unless meta[:contract]

        nested = public_send(attr_name)
        next unless nested.is_a?(ApiContract::Base)

        nested.schema_validate!
      end
    end

    # Validates all nested contracts and propagates errors with
    # dot-notation keys.
    #
    # @return [void]
    def validate_nested_contracts
      self.class.attribute_registry.each do |attr_name, meta|
        next unless meta[:contract]

        propagate_nested_errors(attr_name)
      end
    end

    # Propagates errors from a single nested contract.
    #
    # @param attr_name [Symbol] the parent attribute name
    # @return [void]
    def propagate_nested_errors(attr_name)
      nested = public_send(attr_name)
      return unless nested.is_a?(ApiContract::Base)
      return if nested.valid?

      nested.errors.each do |error|
        errors.add(:"#{attr_name}.#{error.attribute}", error.message)
      end
    end

    # Recursively converts all hash keys to strings.
    #
    # @param hash [Hash] the hash to transform
    # @return [Hash{String => Object}] string-keyed hash
    def deep_stringify_keys(hash)
      hash.each_with_object({}) do |(key, value), result|
        result[key.to_s] = value.is_a?(Hash) ? deep_stringify_keys(value) : value
      end
    end

    # Recursively converts all hash keys to camelCase strings.
    #
    # @param hash [Hash] the hash to transform
    # @return [Hash{String => Object}] camelCase string-keyed hash
    def deep_camelize_keys(hash)
      hash.each_with_object({}) do |(key, value), result|
        result[camelize_key(key)] = value.is_a?(Hash) ? deep_camelize_keys(value) : value
      end
    end
  end
end
