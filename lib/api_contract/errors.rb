# frozen_string_literal: true

module ApiContract
  # Base error class for all ApiContract errors.
  class Error < StandardError; end

  # Raised when one or more required attributes are absent from the input.
  class MissingAttributeError < Error
    # @return [Array<Symbol>] the missing attribute names
    attr_reader :attributes

    # @param message [String] the error message
    # @param attributes [Array<Symbol>] the missing attribute names
    def initialize(message = nil, attributes: [])
      @attributes = attributes
      super(message)
    end
  end

  # Raised when attributes are present that are not declared in the schema.
  class UnexpectedAttributeError < Error
    # @return [Array<Symbol>] the unexpected attribute names
    attr_reader :attributes

    # @param message [String] the error message
    # @param attributes [Array<Symbol>] the unexpected attribute names
    def initialize(message = nil, attributes: [])
      @attributes = attributes
      super(message)
    end
  end

  # Raised when the structural shape is correct but data fails validations
  # or type coercion. Exposes the original contract via {#contract}.
  class InvalidContractError < Error
    # @return [ApiContract::Base] the contract that failed validation
    attr_reader :contract

    # @param message [String] the error message
    # @param contract [ApiContract::Base] the contract that failed validation
    def initialize(message = nil, contract: nil)
      @contract = contract
      super(message)
    end
  end
end
