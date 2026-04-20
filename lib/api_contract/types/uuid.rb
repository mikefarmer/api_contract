# frozen_string_literal: true

module ApiContract
  module Types
    # A UUID-valued attribute type. Casts valid RFC 9562 UUID strings to
    # their lowercase-normalized form and leaves other inputs untouched
    # so {StrictCoercionValidator} can surface them as validation errors.
    #
    # Instances are parameterized by +version:+. When +version+ is +nil+
    # the type accepts any valid UUID (v1-v8, plus the nil and max
    # UUIDs). When +version+ is an Integer in +1..8+ the type accepts
    # only UUIDs with that version nibble and RFC 9562 variant bits.
    #
    # The gem registers +:uuid+ and +:uuid_v1+..+:uuid_v8+ with
    # ActiveModel at load time, so attributes can be declared as
    # +attribute :id, :uuid+ or +attribute :id, :uuid_v7+.
    #
    # @example
    #   ApiContract::Types::UUID.new.cast('F47AC10B-58CC-4372-A567-0E02B2C3D479')
    #   # => "f47ac10b-58cc-4372-a567-0e02b2c3d479"
    #
    #   ApiContract::Types::UUID.new(version: 7).cast('f47ac10b-58cc-4372-a567-0e02b2c3d479')
    #   # => "f47ac10b-58cc-4372-a567-0e02b2c3d479" (passed through; strict coercion rejects)
    class UUID < ActiveModel::Type::Value
      # Matches any canonical 8-4-4-4-12 hex UUID, including the nil
      # and max UUIDs. Case-insensitive.
      UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

      # @return [Integer, nil] the required UUID version, or +nil+ for any
      attr_reader :version

      # Creates a new UUID type.
      #
      # @param version [Integer, nil] required UUID version (+1..8+),
      #   or +nil+ to accept any version
      def initialize(version: nil)
        raise ArgumentError, "invalid UUID version: #{version.inspect}" unless version.nil? || (1..8).cover?(version)

        @version = version
        @regex = self.class.regex_for(version)
        super()
      end

      # Returns a regex matching the given UUID version, or any version
      # when +version+ is +nil+. Version-specific regexes additionally
      # require the RFC 9562 variant bits (17th hex char in +[89ab]+).
      #
      # @param version [Integer, nil]
      # @return [Regexp]
      def self.regex_for(version)
        return UUID_REGEX if version.nil?

        /\A[0-9a-f]{8}-[0-9a-f]{4}-#{version}[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i
      end

      # Casts the input. Returns +nil+ for +nil+, a lowercase copy of
      # the string when it matches the configured UUID format, or the
      # original value unchanged so strict coercion can reject it.
      #
      # @param value [Object] the input value
      # @return [String, nil, Object]
      def cast(value)
        return nil if value.nil?
        return value.downcase if value.is_a?(String) && @regex.match?(value)

        value
      end

      # Returns the type name for metadata. +:uuid+ for the generic
      # type, +:uuid_vN+ for version-specific variants.
      #
      # @return [Symbol]
      def type
        @version.nil? ? :uuid : :"uuid_v#{@version}"
      end
    end
  end
end
