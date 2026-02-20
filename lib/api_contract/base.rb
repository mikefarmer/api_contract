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

    # Returns whether the contract's structure is valid (all required keys
    # present, no unexpected keys).
    #
    # @return [Boolean] true if the schema is valid
    # @raise [NotImplementedError] not yet implemented
    def schema_valid?
      raise NotImplementedError
    end

    # Validates the contract's structure, raising an exception if invalid.
    #
    # @return [void]
    # @raise [ApiContract::MissingAttributeError] if required attributes are absent
    # @raise [ApiContract::UnexpectedAttributeError] if unexpected attributes are present
    # @raise [NotImplementedError] not yet implemented
    def schema_validate!
      raise NotImplementedError
    end
  end
end
