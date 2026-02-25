# frozen_string_literal: true

module ApiContract
  # Generates OpenAPI 3.0 / JSON Schema compatible schema hashes from
  # contract class definitions. Each contract can produce a schema that
  # maps its typed attributes to JSON Schema properties.
  #
  # @example
  #   UserContract.open_api_schema
  #   # => { "type" => "object", "properties" => { ... }, "required" => [...] }
  module OpenApiSchema
    # ActiveModel type to JSON Schema type mapping.
    TYPE_MAP = {
      string: 'string',
      integer: 'integer',
      float: 'number',
      decimal: 'number',
      boolean: 'boolean'
    }.freeze

    # Sets up class-level methods when included.
    #
    # @param base [Class] the including class
    # @return [void]
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level methods for OpenAPI schema generation.
    module ClassMethods
      # Returns an OpenAPI 3.0 / JSON Schema compatible hash describing
      # this contract's structure.
      #
      # @return [Hash{String => Object}] the JSON Schema hash
      #
      # @example
      #   UserContract.open_api_schema
      def open_api_schema
        schema = { 'type' => 'object', 'properties' => {} }
        populate_properties(schema)
        add_required(schema)
        schema
      end

      private

      # Populates the properties hash in the schema.
      #
      # @param schema [Hash] the schema hash to populate
      # @return [void]
      def populate_properties(schema)
        attribute_registry.each do |name, meta|
          schema['properties'][name.to_s] = property_for(meta)
        end
      end

      # Adds the required array to the schema if any attributes are required.
      #
      # @param schema [Hash] the schema hash
      # @return [void]
      def add_required(schema)
        required = required_attribute_names.map(&:to_s)
        schema['required'] = required if required.any?
      end

      # Builds a JSON Schema property hash for a single attribute.
      #
      # @param meta [Hash] the attribute metadata from the registry
      # @return [Hash{String => Object}] the property schema
      def property_for(meta)
        prop = build_type_schema(meta)
        prop['description'] = meta[:description] if meta[:description]
        prop['readOnly'] = true if meta[:type] == :computed
        prop
      end

      # Builds the type-specific portion of a property schema.
      #
      # @param meta [Hash] the attribute metadata
      # @return [Hash{String => Object}] the type schema
      def build_type_schema(meta)
        case meta[:type]
        when :contract then contract_schema(meta)
        when :array then array_schema(meta)
        when :permissive_hash then { 'type' => 'object' }
        when :computed then computed_schema(meta)
        else scalar_schema(meta)
        end
      end

      # Builds schema for a scalar (string, integer, etc.) attribute.
      #
      # @param meta [Hash] the attribute metadata
      # @return [Hash{String => String}] the scalar schema
      def scalar_schema(meta)
        json_type = TYPE_MAP[meta[:type]]
        json_type ? { 'type' => json_type } : { 'type' => 'string' }
      end

      # Builds schema for a nested contract attribute.
      #
      # @param meta [Hash] the attribute metadata
      # @return [Hash{String => Object}] the contract ref or oneOf schema
      def contract_schema(meta)
        ref = meta[:contract]
        return one_of_schema(ref) if ref.is_a?(ApiContract::OneOf)

        { '$ref' => ref_path(ref) }
      end

      # Builds schema for a oneOf polymorphic attribute.
      #
      # @param one_of [ApiContract::OneOf] the oneOf descriptor
      # @return [Hash{String => Array}] the oneOf schema
      def one_of_schema(one_of)
        refs = one_of.candidates.map { |c| { '$ref' => ref_path(c) } }
        { 'oneOf' => refs }
      end

      # Builds schema for an array attribute.
      #
      # @param meta [Hash] the attribute metadata
      # @return [Hash{String => Object}] the array schema
      def array_schema(meta)
        items = array_items_schema(meta[:element_type])
        { 'type' => 'array', 'items' => items }
      end

      # Builds the items schema for array elements.
      #
      # @param element_type [Symbol] the element type
      # @return [Hash{String => String}] the items schema
      def array_items_schema(element_type)
        return {} if element_type == :permissive

        json_type = TYPE_MAP[element_type]
        json_type ? { 'type' => json_type } : { 'type' => 'string' }
      end

      # Builds schema for a computed attribute. Uses the return type
      # if determinable, otherwise defaults to string.
      #
      # @param _meta [Hash] the attribute metadata
      # @return [Hash{String => String}] the computed schema
      def computed_schema(_meta)
        { 'type' => 'string' }
      end

      # Builds a JSON Schema $ref path for a contract class or string.
      #
      # @param reference [Class, String] the contract reference
      # @return [String] the $ref path
      def ref_path(reference)
        name = reference.is_a?(Class) ? reference.name : reference.to_s
        "#/components/schemas/#{name}"
      end
    end
  end
end
