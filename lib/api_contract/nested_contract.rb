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
    # Arrays of nested contracts are mapped element-wise.
    #
    # @return [Hash{Symbol => Object}] symbolized attribute hash
    def to_h
      super.transform_values { |v| serialize_nested_value(v) }
    end

    # Recursively converts nested contract values to plain hashes or
    # arrays of hashes, leaving other values untouched.
    #
    # @param value [Object] the attribute value
    # @return [Object] the serialized representation
    def serialize_nested_value(value)
      case value
      when ApiContract::Base then value.to_h
      when Array then value.map { |element| serialize_nested_value(element) }
      else value
      end
    end

    private

    # Instantiates nested contracts from hash values during initialization.
    #
    # @return [void]
    def instantiate_nested_contracts!
      self.class.attribute_registry.each do |attr_name, meta|
        next unless nested_contract_attribute?(meta)

        if meta[:type] == :contract_array
          instantiate_nested_array_attribute(attr_name, meta)
        else
          instantiate_nested_attribute(attr_name, meta)
        end
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

      nested = build_nested_contract(meta[:contract], value, meta[:permissive])
      _write_attribute(attr_name.to_s, nested)
    end

    # Instantiates an array-of-contracts attribute. Hash elements are
    # converted to contract instances; already-instantiated contracts and
    # other values are passed through unchanged so strict coercion can
    # surface any remaining issues.
    #
    # @param attr_name [Symbol] the attribute name
    # @param meta [Hash] the attribute metadata
    # @return [void]
    def instantiate_nested_array_attribute(attr_name, meta)
      value = public_send(attr_name)
      return unless value.is_a?(Array)

      nested = value.map do |element|
        next element unless element.is_a?(Hash)

        build_nested_contract(meta[:contract], element, meta[:permissive])
      end
      _write_attribute(attr_name.to_s, nested)
    end

    # Builds a single nested contract from a hash, dispatching on whether
    # the reference is a {OneOf} descriptor or a direct class/string ref.
    #
    # @param contract_ref [Class, String, ApiContract::OneOf] the reference
    # @param value [Hash] the input hash
    # @param permissive [Boolean] whether to fall back to a plain hash
    # @return [ApiContract::Base, Hash]
    def build_nested_contract(contract_ref, value, permissive)
      if contract_ref.is_a?(ApiContract::OneOf)
        resolve_one_of(contract_ref, value, permissive)
      else
        self.class.resolve_contract(contract_ref).new(value)
      end
    end

    # Returns whether an attribute holds a nested contract or an array of
    # nested contracts.
    #
    # @param meta [Hash] the attribute metadata
    # @return [Boolean]
    def nested_contract_attribute?(meta)
      meta[:contract] && %i[contract contract_array].include?(meta[:type])
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
    # Arrays of contracts are recursed element-wise.
    #
    # @return [void]
    # @raise [ApiContract::MissingAttributeError]
    # @raise [ApiContract::UnexpectedAttributeError]
    def validate_nested_schemas!
      self.class.attribute_registry.each do |attr_name, meta|
        next unless nested_contract_attribute?(meta)

        nested = public_send(attr_name)
        if nested.is_a?(Array)
          nested.each { |element| element.schema_validate! if element.is_a?(ApiContract::Base) }
        elsif nested.is_a?(ApiContract::Base)
          nested.schema_validate!
        end
      end
    end

    # Validates all nested contracts and propagates errors with
    # dot-notation keys. Arrays of contracts use +key[index].field+.
    #
    # @return [void]
    def validate_nested_contracts
      self.class.attribute_registry.each do |attr_name, meta|
        next unless nested_contract_attribute?(meta)

        propagate_nested_errors(attr_name)
      end
    end

    # Propagates errors from a single nested contract or array of
    # nested contracts.
    #
    # @param attr_name [Symbol] the parent attribute name
    # @return [void]
    def propagate_nested_errors(attr_name)
      nested = public_send(attr_name)
      if nested.is_a?(Array)
        nested.each_with_index do |element, index|
          propagate_errors_from(element, "#{attr_name}[#{index}]")
        end
      else
        propagate_errors_from(nested, attr_name.to_s)
      end
    end

    # Propagates errors from a single nested contract under the given key prefix.
    #
    # @param nested [Object] the nested value
    # @param prefix [String] the error key prefix
    # @return [void]
    def propagate_errors_from(nested, prefix)
      return unless nested.is_a?(ApiContract::Base)
      return if nested.valid?

      nested.errors.each do |error|
        errors.add(:"#{prefix}.#{error.attribute}", error.message)
      end
    end
  end
end
