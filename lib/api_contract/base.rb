# frozen_string_literal: true

module ApiContract
  # Base class for all API contracts. Provides typed, validated, immutable
  # data transfer objects with ActiveModel integration.
  #
  # Subclass this to define contracts with typed attributes, validations,
  # and serialization behavior.
  #
  # @abstract Subclass and declare attributes to define a contract.
  #
  # @example
  #   class UserContract < ApiContract::Base
  #     attribute :name, :string
  #     attribute :email, :string
  #   end
  class Base
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations::Callbacks
    include AttributeRegistry

    # Constructs a new contract instance. Never raises an exception,
    # regardless of which attributes are passed.
    #
    # Symbolizes incoming keys, separates known from unexpected attributes,
    # and tracks which keys were explicitly provided. When a key's value is
    # +nil+ and the attribute has a +default:+, the key is omitted so that
    # ActiveModel applies the default.
    #
    # @param attrs [Hash] the input attributes
    def initialize(attrs = {})
      known, provided, unexpected = partition_attributes(attrs)
      @_provided_keys = provided.freeze
      @_unexpected_keys = unexpected.freeze
      super(known)
    end

    # Constructs a contract from ActionController::Parameters, calling
    # {#schema_validate!} internally.
    #
    # @param _params [ActionController::Parameters] the request parameters
    # @return [ApiContract::Base] a new immutable contract instance
    # @raise [NotImplementedError] not yet implemented
    def self.from_params(_params)
      raise NotImplementedError
    end

    # Constructs a contract from a JSON string, calling
    # {#schema_validate!} internally.
    #
    # @param _json [String] a JSON string
    # @return [ApiContract::Base] a new immutable contract instance
    # @raise [NotImplementedError] not yet implemented
    def self.from_json(_json)
      raise NotImplementedError
    end

    # Returns the set of attribute keys that were explicitly provided
    # during construction (after symbolization).
    #
    # @return [Set<Symbol>] explicitly provided keys
    def provided_keys
      @_provided_keys
    end

    # Returns whether a specific attribute was explicitly provided
    # during construction.
    #
    # @param name [Symbol] the attribute name
    # @return [Boolean] true if the key was explicitly provided
    def provided?(name)
      @_provided_keys.include?(name.to_sym)
    end

    # Returns a hash of attributes that were passed to the constructor
    # but are not declared in the schema.
    #
    # @return [Hash{Symbol => Object}] unexpected attribute names and values
    def unexpected_attributes
      @_unexpected_keys
    end

    # Returns a hash of schema errors. Keys are attribute names, values
    # are arrays of error message strings.
    #
    # @return [Hash{Symbol => Array<String>}] schema error messages
    def schema_errors
      errors_hash = {}
      missing_attribute_names.each { |name| errors_hash[name] = ['is missing'] }
      @_unexpected_keys.each_key { |name| errors_hash[name] = ['is unexpected'] }
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
    # Missing attributes are checked before unexpected attributes.
    #
    # @return [void]
    # @raise [ApiContract::MissingAttributeError] if required attributes are absent
    # @raise [ApiContract::UnexpectedAttributeError] if unexpected attributes are present
    def schema_validate!
      validate_no_missing_attributes!
      validate_no_unexpected_attributes!
    end

    private

    # Partitions the input hash into known attributes, provided keys,
    # and unexpected attributes.
    #
    # @param attrs [Hash, nil] raw input attributes
    # @return [Array(Hash, Set, Hash)] known, provided, unexpected
    def partition_attributes(attrs)
      attrs = (attrs || {}).transform_keys(&:to_sym)
      known = {}
      unexpected = {}
      provided = Set.new

      attrs.each { |key, value| classify_attribute(key, value, known, provided, unexpected) }
      [known, provided, unexpected]
    end

    # Classifies a single attribute into the known, provided, or
    # unexpected bucket.
    #
    # @param key [Symbol] the attribute name
    # @param value [Object] the attribute value
    # @param known [Hash] accumulator for declared attributes
    # @param provided [Set] accumulator for explicitly provided keys
    # @param unexpected [Hash] accumulator for undeclared attributes
    # @return [void]
    def classify_attribute(key, value, known, provided, unexpected)
      if self.class.declared_attribute_names.include?(key)
        meta = self.class.attribute_registry[key]
        unless value.nil? && meta[:has_default]
          known[key] = value
          provided << key
        end
      else
        unexpected[key] = value
      end
    end

    # Returns the names of required attributes that were not provided.
    #
    # @return [Array<Symbol>] missing required attribute names
    def missing_attribute_names
      self.class.required_attribute_names.reject { |name| @_provided_keys.include?(name) }
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
      return if @_unexpected_keys.empty?

      unexpected = @_unexpected_keys.keys
      raise UnexpectedAttributeError.new(
        "Unexpected attribute(s): #{unexpected.join(', ')}",
        attributes: unexpected
      )
    end
  end
end
