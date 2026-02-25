# frozen_string_literal: true

module ApiContract
  # Descriptor for polymorphic nested contracts. Returned by the +one_of+
  # class method and used by the +contract:+ attribute option.
  #
  # During instantiation, each candidate contract is tried in declaration
  # order. The first candidate whose +schema_validate!+ does not raise is
  # used. If no candidate matches, behavior depends on the +permissive+
  # flag.
  #
  # @example
  #   attribute :address, contract: one_of('USAddress', 'UKAddress')
  class OneOf
    # @return [Array<Class, String>] the candidate contract references
    attr_reader :candidates

    # @param candidates [Array<Class, String>] contract classes or string names
    def initialize(*candidates)
      @candidates = candidates
    end

    # Attempts to resolve the input hash against each candidate contract.
    # Returns the first contract instance whose +schema_validate!+ succeeds.
    #
    # @param hash [Hash] the input hash to resolve
    # @param resolver [#resolve_contract] the class that can resolve string refs
    # @return [ApiContract::Base, nil] the matched contract, or nil if none match
    def resolve(hash, resolver:)
      candidates.each do |ref|
        result = try_candidate(hash, resolver, ref)
        return result if result
      end
      nil
    end

    private

    # Tries a single candidate contract against the input hash.
    #
    # @param hash [Hash] the input hash
    # @param resolver [#resolve_contract] the class that can resolve string refs
    # @param ref [Class, String] the candidate contract reference
    # @return [ApiContract::Base, nil] the matched contract, or nil
    def try_candidate(hash, resolver, ref)
      contract_class = resolver.resolve_contract(ref)
      instance = contract_class.new(hash)
      instance.schema_validate!
      instance
    rescue MissingAttributeError, UnexpectedAttributeError
      nil
    end
  end
end
