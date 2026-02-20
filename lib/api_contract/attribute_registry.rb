# frozen_string_literal: true

module ApiContract
  # Stores class-level metadata for declared attributes, including custom
  # options like +optional:+, +description:+, and +default:+.
  #
  # Included automatically by {ApiContract::Base}. Override of +attribute+
  # extracts custom options before delegating to +ActiveModel::Attributes+.
  #
  # @example
  #   class MyContract < ApiContract::Base
  #     attribute :name, :string, description: "Full name"
  #     attribute :age,  :integer, optional: true
  #   end
  #
  #   MyContract.attribute_registry
  #   # => { name: { type: :string, optional: false, description: "Full name", ... }, ... }
  module AttributeRegistry
    # Custom options extracted from the +attribute+ call before delegating
    # to ActiveModel.
    CUSTOM_OPTIONS = %i[optional description].freeze

    # Class-level methods mixed into the including class.
    module ClassMethods
      # Declares a typed attribute with optional custom metadata.
      #
      # Extracts +optional:+ and +description:+ from the options hash,
      # stores them in the attribute registry, and forwards the remaining
      # options (including +default:+) to +ActiveModel::Attributes#attribute+.
      #
      # @param name [Symbol] the attribute name
      # @param type [Symbol] the ActiveModel type (e.g. +:string+, +:integer+)
      # @param options [Hash] attribute options
      # @option options [Boolean] :optional (false) whether the attribute is optional
      # @option options [String] :description human-readable description
      # @option options [Object] :default default value (handled by ActiveModel)
      # @return [void]
      def attribute(name, type = :value, **options)
        store_attribute_metadata(name, type, options)
        super
      end

      # Returns the full metadata hash for all declared attributes.
      #
      # @return [Hash{Symbol => Hash}] attribute name to metadata mapping
      def attribute_registry
        @attribute_registry ||= {}
      end

      # Returns the names of attributes that are required — not optional and
      # have no default value.
      #
      # @return [Array<Symbol>] required attribute names
      def required_attribute_names
        attribute_registry.each_with_object([]) do |(name, meta), arr|
          arr << name unless meta[:optional] || meta[:has_default]
        end
      end

      # Returns the names of all declared attributes.
      #
      # @return [Array<Symbol>] all declared attribute names
      def declared_attribute_names
        attribute_registry.keys
      end

      private

      # Extracts custom options and stores metadata in the registry.
      #
      # @param name [Symbol] the attribute name
      # @param type [Symbol] the ActiveModel type
      # @param options [Hash] the full options hash (custom keys are deleted)
      # @return [void]
      def store_attribute_metadata(name, type, options)
        attribute_registry[name.to_sym] = {
          type: type,
          optional: options.delete(:optional) || false,
          description: options.delete(:description),
          has_default: options.key?(:default),
          default: options[:default]
        }
      end

      # Inherits the parent's attribute registry on subclassing, performing
      # a deep copy so mutations in the child do not affect the parent.
      #
      # @param subclass [Class] the new subclass
      # @return [void]
      def inherited(subclass)
        super
        subclass.instance_variable_set(
          :@attribute_registry,
          attribute_registry.transform_values(&:dup)
        )
      end
    end

    # @private
    def self.included(base)
      base.extend(ClassMethods)
    end
  end
end
