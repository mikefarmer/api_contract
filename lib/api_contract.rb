# frozen_string_literal: true

require 'active_model'
require 'json'

require_relative 'api_contract/version'
require_relative 'api_contract/errors'
require_relative 'api_contract/types/strict_coercion_validator'
require_relative 'api_contract/types/permissive_array'
require_relative 'api_contract/types/permissive_hash'
require_relative 'api_contract/types/typed_array'
require_relative 'api_contract/attribute_registry'
require_relative 'api_contract/strict_coercion'
require_relative 'api_contract/schema_validation'
require_relative 'api_contract/serialization'
require_relative 'api_contract/immutability'
require_relative 'api_contract/normalizers'
require_relative 'api_contract/one_of'
require_relative 'api_contract/computed'
require_relative 'api_contract/nested_contract'
require_relative 'api_contract/permissive_attributes'
require_relative 'api_contract/base'

# Typed, validated, immutable data transfer objects with Rails integration.
module ApiContract
end
