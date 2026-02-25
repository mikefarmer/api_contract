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
    include StrictCoercion
    include SchemaValidation
    include Serialization
    include Immutability
    include Normalizers
    include NestedContract
    include Computed

    # Constructs a new contract instance. Never raises an exception,
    # regardless of which attributes are passed.
    #
    # @param attrs [Hash] the input attributes
    def initialize(attrs = {})
      known, provided, unexpected = partition_attributes(attrs)
      @_provided_keys = provided.freeze
      @_unexpected_keys = unexpected.freeze
      capture_raw_attributes(known)
      super(known)
      instantiate_nested_contracts!
      apply_normalizers!
      freeze_contract!
    end

    # Returns a {OneOf} descriptor for polymorphic nested contracts.
    #
    # @param contracts [Array<Class, String>] candidate contract classes or string names
    # @return [ApiContract::OneOf] a polymorphic contract descriptor
    #
    # @example
    #   attribute :address, contract: one_of('USAddress', 'UKAddress')
    def self.one_of(*contracts)
      OneOf.new(*contracts)
    end

    # Constructs a contract from ActionController::Parameters or a plain hash,
    # calling {#schema_validate!} and data validations internally.
    #
    # @param params [ActionController::Parameters, Hash] the request parameters
    # @return [ApiContract::Base] a validated contract instance
    # @raise [ApiContract::MissingAttributeError] if required attributes are absent
    # @raise [ApiContract::UnexpectedAttributeError] if unexpected attributes are present
    # @raise [ApiContract::InvalidContractError] if data validations fail
    def self.from_params(params)
      attrs = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
      instance = new(attrs)
      instance.schema_validate!
      validate_contract!(instance)
      instance
    end

    # Constructs a contract from a JSON string, calling {#schema_validate!}
    # and data validations internally.
    #
    # @param json [String] a JSON string
    # @return [ApiContract::Base] a validated contract instance
    # @raise [JSON::ParserError] if the JSON string is malformed
    # @raise [ApiContract::MissingAttributeError] if required attributes are absent
    # @raise [ApiContract::UnexpectedAttributeError] if unexpected attributes are present
    # @raise [ApiContract::InvalidContractError] if data validations fail
    def self.from_json(json)
      attrs = JSON.parse(json)
      instance = new(attrs)
      instance.schema_validate!
      validate_contract!(instance)
      instance
    end

    # Validates the contract instance and raises {InvalidContractError} if invalid.
    #
    # @param instance [ApiContract::Base] the contract to validate
    # @return [void]
    # @raise [ApiContract::InvalidContractError] if data validations fail
    private_class_method def self.validate_contract!(instance)
      return if instance.valid?

      messages = instance.errors.map { |error| "#{error.attribute} #{error.message}" }
      raise InvalidContractError.new(
        "Contract validation failed: #{messages.join(', ')}",
        contract: instance
      )
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
      meta = self.class.attribute_registry[key]
      if meta
        return if meta[:type] == :computed

        unless value.nil? && meta[:has_default]
          known[key] = value
          provided << key
        end
      else
        unexpected[key] = value
      end
    end
  end
end
