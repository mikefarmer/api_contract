# frozen_string_literal: true

module ApiContract
  # Makes contracts immutable by default with controlled mutation paths.
  # Contracts created via +.new+, +.from_params+, or +.from_json+ are
  # read-only. Attribute writers raise +FrozenError+ on immutable contracts.
  #
  # Mutation is available through +#clone+, +#mutate+, +#merge+, and +#dup+.
  #
  # Included automatically by {ApiContract::Base}.
  module Immutability
    # Returns whether this contract is read-only (immutable).
    #
    # @return [Boolean] true if the contract is immutable
    def read_only?
      @_read_only == true
    end

    # Returns a new immutable contract with the given attributes merged
    # over the current values. Calls +schema_validate!+ on the result.
    #
    # @param changes [Hash{Symbol => Object}] attributes to change
    # @return [ApiContract::Base] a new immutable contract
    # @raise [ApiContract::MissingAttributeError] if required attributes are absent
    # @raise [ApiContract::UnexpectedAttributeError] if unexpected attributes are present
    def clone(**changes)
      instance = self.class.new(to_h.merge(changes))
      instance.schema_validate!
      instance
    end

    # Returns a new immutable contract with the given attributes changed.
    # Requires at least one changed attribute. Calls +schema_validate!+
    # on the result.
    #
    # @param changes [Hash{Symbol => Object}] attributes to change (required)
    # @return [ApiContract::Base] a new immutable contract
    # @raise [ArgumentError] if no changes are provided
    # @raise [ApiContract::MissingAttributeError] if required attributes are absent
    # @raise [ApiContract::UnexpectedAttributeError] if unexpected attributes are present
    def mutate(**changes)
      raise ArgumentError, 'must provide at least one attribute to change' if changes.empty?

      clone(**changes)
    end

    # Deep merges another contract (or hash) into this one, returning a new
    # immutable contract. The argument's values always win on conflict,
    # including +nil+.
    #
    # @param other [ApiContract::Base, Hash] the contract or hash to merge
    # @param strict [Boolean] whether to call +schema_validate!+ (default: true)
    # @param validate [Boolean] whether to call +valid?+ (default: true)
    # @return [ApiContract::Base] a new immutable contract
    # @raise [ApiContract::MissingAttributeError] if strict and required attributes are absent
    # @raise [ApiContract::UnexpectedAttributeError] if strict and unexpected attributes are present
    # @raise [ApiContract::InvalidContractError] if validate and data validations fail
    def merge(other, strict: true, validate: true)
      other_hash = other.is_a?(ApiContract::Base) ? other.to_h : other.transform_keys(&:to_sym)
      merged = deep_merge_hashes(to_h, other_hash)
      build_merged_contract(merged, strict: strict, validate: validate)
    end

    private

    # Freezes the contract after initialization.
    #
    # @return [void]
    def freeze_contract!
      @_read_only = true
    end

    # Called by Ruby's +dup+ to initialize the copy. Sets the copy
    # to mutable and deep-dups the ActiveModel attributes.
    #
    # @param source [ApiContract::Base] the original contract
    # @return [void]
    def initialize_dup(source)
      super
      @_read_only = false
    end

    # Guard for attribute writers. Raises +FrozenError+ when the
    # contract is read-only.
    #
    # @param attr_name [String] the attribute name
    # @param value [Object] the value being written
    # @return [void]
    # @raise [FrozenError] if the contract is read-only
    def _write_attribute(attr_name, value)
      raise FrozenError, "can't modify read-only contract" if @_read_only

      super
    end

    # Recursively merges two hashes. The +other+ hash always wins on conflict.
    #
    # @param base [Hash] the base hash
    # @param other [Hash] the hash to merge in (wins on conflict)
    # @return [Hash] the merged result
    def deep_merge_hashes(base, other)
      base.merge(other) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge_hashes(old_val, new_val)
        else
          new_val
        end
      end
    end

    # Builds a merged contract with optional schema and data validation.
    #
    # @param attrs [Hash] the merged attributes
    # @param strict [Boolean] whether to run schema validation
    # @param validate [Boolean] whether to run data validation
    # @return [ApiContract::Base] the merged contract
    def build_merged_contract(attrs, strict:, validate:)
      instance = self.class.new(attrs)
      instance.schema_validate! if strict
      validate_merged_contract!(instance) if validate
      instance
    end

    # Validates a merged contract and raises if invalid.
    #
    # @param instance [ApiContract::Base] the contract to validate
    # @return [void]
    # @raise [ApiContract::InvalidContractError] if data validations fail
    def validate_merged_contract!(instance)
      return if instance.valid?

      messages = instance.errors.map { |error| "#{error.attribute} #{error.message}" }
      raise InvalidContractError.new(
        "Contract validation failed: #{messages.join(', ')}",
        contract: instance
      )
    end
  end
end
