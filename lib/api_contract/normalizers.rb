# frozen_string_literal: true

module ApiContract
  # Provides the +normalizes+ DSL for transforming attribute values during
  # initialization. Normalizers run after type coercion but before the
  # contract is frozen.
  #
  # Included automatically by {ApiContract::Base}.
  #
  # @example
  #   class UserContract < ApiContract::Base
  #     attribute :email, :string
  #     normalizes :email, with: ->(email) { email.strip.downcase }
  #   end
  module Normalizers
    # Sets up class-level normalizer storage when included.
    #
    # @param base [Class] the including class
    # @return [void]
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level methods for declaring normalizers.
    module ClassMethods
      # Declares a normalizer for one or more attributes. The normalizer
      # is a lambda that receives the current value and returns the
      # transformed value.
      #
      # @param attr_names [Array<Symbol>] attribute names to normalize
      # @param with [Proc] the normalizer lambda
      # @return [void]
      #
      # @example
      #   normalizes :email, with: ->(email) { email.strip.downcase }
      #   normalizes :first_name, :last_name, with: ->(name) { name.strip }
      def normalizes(*attr_names, with:)
        attr_names.each do |attr_name|
          normalizer_registry[attr_name.to_sym] = with
        end
      end

      # Returns the normalizer registry for this class.
      #
      # @return [Hash{Symbol => Proc}] attribute name to normalizer mapping
      def normalizer_registry
        @normalizer_registry ||= {}
      end

      private

      # Inherits the parent's normalizer registry on subclassing.
      #
      # @param subclass [Class] the new subclass
      # @return [void]
      def inherited(subclass)
        super
        subclass.instance_variable_set(
          :@normalizer_registry,
          normalizer_registry.dup
        )
      end
    end

    private

    # Applies all registered normalizers to the contract's attributes.
    # Skips normalizers for nil values.
    #
    # @return [void]
    def apply_normalizers!
      self.class.normalizer_registry.each do |attr_name, normalizer|
        value = public_send(attr_name)
        next if value.nil?

        _write_attribute(attr_name.to_s, normalizer.call(value))
      end
    end
  end
end
