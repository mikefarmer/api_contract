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
    CUSTOM_OPTIONS = %i[optional description array].freeze

    # Class-level methods mixed into the including class.
    module ClassMethods
      # Declares a typed attribute with optional custom metadata.
      #
      # Extracts +optional:+, +description:+, and +array:+ from the
      # options hash, stores them in the attribute registry, and forwards
      # the remaining options to +ActiveModel::Attributes#attribute+.
      #
      # When +array:+ is provided with a type symbol, the attribute uses
      # a {Types::TypedArray} parameterized with that element type. When
      # +array: :permissive+ is used, the attribute accepts any array
      # elements without coercion or validation.
      #
      # @param name [Symbol] the attribute name
      # @param type [Symbol] the ActiveModel type (e.g. +:string+, +:integer+)
      # @param options [Hash] attribute options
      # @option options [Boolean] :optional (false) whether the attribute is optional
      # @option options [String] :description human-readable description
      # @option options [Symbol] :array element type for typed arrays, or +:permissive+
      # @option options [Object] :default default value (handled by ActiveModel)
      # @return [void]
      def attribute(name, type = :value, **options)
        element_type = options.delete(:array)
        if element_type
          array_type = build_array_type(element_type)
          store_attribute_metadata(name, :array, options, element_type: element_type)
          super(name, array_type, **options)
        else
          store_attribute_metadata(name, type, options)
          super
        end
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

      # Builds the appropriate array type instance for the given element type.
      #
      # @param element_type [Symbol] +:permissive+ or an ActiveModel type symbol
      # @return [Types::PermissiveArray, Types::TypedArray]
      def build_array_type(element_type)
        if element_type == :permissive
          Types::PermissiveArray.new
        else
          Types::TypedArray.new(element_type: element_type)
        end
      end

      # Extracts custom options and stores metadata in the registry.
      #
      # @param name [Symbol] the attribute name
      # @param type [Symbol] the ActiveModel type
      # @param options [Hash] the full options hash (custom keys are deleted)
      # @param element_type [Symbol, nil] the element type for typed arrays
      # @return [void]
      def store_attribute_metadata(name, type, options, element_type: nil)
        attribute_registry[name.to_sym] = {
          type: type,
          optional: options.delete(:optional) || false,
          description: options.delete(:description),
          has_default: options.key?(:default),
          default: options[:default],
          element_type: element_type
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
