# ApiContract

[![Gem Version](https://badge.fury.io/rb/api_contract.svg)](https://badge.fury.io/rb/api_contract)
[![CI](https://github.com/turbo/api_contract/actions/workflows/ci.yml/badge.svg)](https://github.com/turbo/api_contract/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A Ruby gem for defining typed, validated, immutable data transfer objects (DTOs) with first-class Rails integration. Contracts are a drop-in replacement for `ActionController::Parameters` (StrongParameters) that bring type coercion, structural validation, and immutability to controller boundaries — distinct from ActiveRecord validations, which guard persistence.

## Installation

```ruby
gem 'api_contract'
```

## Overview

Contracts describe the shape of data crossing boundaries in your application — incoming API parameters, outgoing API responses, service inputs and outputs. They provide:

- **Drop-in replacement for StrongParameters** — `from_params` replaces `params.require(...).permit(...)` with a schema-enforced, typed contract
- **Type coercion** via ActiveModel::Attributes
- **Structural validation** (schema-level: missing or unexpected keys)
- **Data validation** (value-level: format, inclusion, length)
- **Immutability by default** with explicit, controlled mutation paths
- **OpenAPI schema generation** — generate JSON Schema from any contract, integrate with RSwag, or build a custom generator
- **Nested contract composition**

### Replacing StrongParameters

StrongParameters protects against mass assignment but does nothing to enforce types, validate values, or document the expected shape. Contracts replace the entire `require`/`permit` pattern with a single, reusable, self-documenting class:

```ruby
# Before: StrongParameters
def user_params
  params.require(:user).permit(:name, :email, :age)
end

# After: ApiContract
user_contract = UserContract.from_params(params)
```

`from_params` calls `schema_validate!` internally, raising immediately if the shape is wrong (`MissingAttributeError`, `UnexpectedAttributeError`). It then coerces all values to their declared types, runs normalizers, and returns a typed object ready to pass to a service. Calling `to_params` on any contract returns a pre-permitted `ActionController::Parameters` instance, making Contracts fully compatible with existing code that expects StrongParameters downstream.

## Defining Contracts

Create a base contract for shared constants and behavior, then inherit from it:

```ruby
# app/contracts/application_contract.rb
class ApplicationContract < ApiContract::Base
  EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
end

# app/contracts/user_contract.rb
class UserContract < ApplicationContract
  attribute :name,               :string,          description: "User's full name"
  attribute :age,                :integer,         optional: true, description: "User's age"
  attribute :email,              :string,          description: "Email address"
  attribute :home_address,       contract: 'AddressContract', description: "User's home address"
  attribute :health_information, :permissive_hash,    optional: true, description: "Any health information"
  attribute :favorite_foods,     array: :string,      description: "Favorite foods, max 3"
  attribute :random_stuff,       array: :permissive,  optional: true, description: "Any array data"

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :favorite_foods, max_length: 3, min_length: 0
  validates :email, format: EMAIL_REGEX
end
```

### Attribute Options

| Option | Description |
|---|---|
| `type` (positional) | ActiveModel type or special type (`:string`, `:integer`, `:permissive_hash`, etc.) |
| `optional: true` | Attribute may be absent; no `MissingAttributeError` is raised and it is excluded from serialization when nil |
| `default:` | Value used when the attribute is absent or explicitly `nil`; implies presence, suppresses `MissingAttributeError` |
| `description:` | Human-readable description, included in OpenAPI schema output |
| `array:` | Declares a typed array attribute (e.g., `array: :string`) |
| `contract:` | Declares a nested contract by class or string reference |

Attributes are **required by default**. Omitting `optional: true` and providing no `default` means the attribute must be present during `from_params` or `from_json` deserialization.

## Instantiation

### `.new` — never raises

`.new` **never raises an exception**, regardless of what attributes are passed. It is safe to use for internal construction, testing, and anywhere you need to inspect validity yourself.

Two separate validity checks are available after construction:

```ruby
contract = UserContract.new(attrs)

# Schema validity — are the right keys present and no unexpected keys?
contract.schema_valid?  # => true / false
contract.schema_errors  # => { name: ["is missing"] }

# Data validity — do the values pass validations?
# Only meaningful when schema_valid? is true
contract.valid?   # => true / false
contract.errors   # => { email: ["is invalid"] }
```

`valid?` pertains exclusively to ActiveModel validations and type coercion. It says nothing about whether the contract's structure is correct. Always check `schema_valid?` before relying on `valid?`.

To raise on schema errors, call `schema_validate!` explicitly:

```ruby
contract.schema_validate! # => raises ApiContract::MissingAttributeError or ApiContract::UnexpectedAttributeError
```

### `from_params` and `from_json` — strict deserialization

`from_params` and `from_json` call `schema_validate!` internally. They raise immediately if the shape is wrong, then return the contract:

```ruby
# Calls schema_validate! internally
contract = UserContract.from_params(params)
contract = UserContract.from_json(json_string)
contract = UserContract.from_camelized_json(json_string) # mirrors as_camelcase_json; keys are converted from camelCase to snake_case before deserialization
```

These are the appropriate entry points at controller and API boundaries where structural correctness must be enforced before the data is used.

## Rails Integration

### Controllers

```ruby
class UsersController < ApplicationController
  def create
    user_contract = UserContract.from_params(params)
    user = CreateUserService.call(user_contract)
    render json: UserResponseContract.from_model(user)
  end

  # Schema violations — wrong shape, missing or unexpected keys
  rescue_from ApiContract::MissingAttributeError, ApiContract::UnexpectedAttributeError do |e|
    render json: ApiErrorResponseContract.from_error(e), status: :bad_request
  end

  # Valid shape, invalid data — failed validations or type coercion errors
  rescue_from ApiContract::InvalidContractError do |e|
    response_contract = ApiErrorResponseContract.from_error(e)
    render json: response_contract, status: response_contract.status
  end
end
```

The two rescue paths reflect a meaningful distinction: schema violations indicate a programming error or malformed client request, while `InvalidContractError` indicates data that passed structural inspection but failed validation rules.

### Response Contracts

Use contracts to shape outgoing responses as well as incoming requests:

```ruby
class UserResponseContract < ApplicationContract
  attribute :id, :string, description: "UUID of the user"

  def self.from_model(user)
    new(id: user.id)
  end
end
```

## Serialization

```ruby
contract.to_h                 # => { name: "Bob", age: 25, ... }
contract.as_json              # => { "name" => "Bob", ... }         raises InvalidContractError if invalid
contract.to_json              # => JSON string                       raises InvalidContractError if invalid
contract.as_camelcase_json    # => { "firstName" => ... }           raises InvalidContractError if invalid

# Deserialize camelCase JSON — mirrors as_camelcase_json
UserContract.from_camelized_json(json_string)

# StrongParameters interop
contract.to_params            # => ActionController::Parameters (pre-permitted)
contract.to_params.permitted? # => true if schema_valid?, false otherwise
```

Serialization methods raise `ApiContract::InvalidContractError` when called on an invalid contract. Use `valid?` and `errors` to inspect state before serializing, or rescue the exception at the appropriate boundary.

`to_params` returns a pre-permitted `ActionController::Parameters` instance. The structure mirrors whatever Rails' `ActionController::Parameters` would produce natively for the same data — nested contracts become nested `ActionController::Parameters` objects, and typed arrays become arrays of the appropriate type. This ensures that any code consuming the result behaves identically to code that received the params directly from a controller, with no further `permit` calls required.

### Traversal

```ruby
contract.attributes  # => [:name, :age, :email, :home_address]
contract.values      # => ["Bob", 25, "bob@example.com", ...]

# dig delegates to to_h.dig
contract.dig(:home_address, :street, 0) # => "123 Main St"
```

## Immutability

Contracts created with `new`, `from_params`, or `from_json` are immutable by default:

```ruby
contract.read_only? # => true
```

### Controlled Mutation

```ruby
# Clone with changed attributes — returns a new immutable contract
# Calls schema_validate! internally; raises ApiContract::MissingAttributeError if structurally invalid
contract.clone(age: 26)

# Merge two contracts — deep merges the argument into the receiver, argument always wins
# By default calls schema_validate! and valid? on the result; both can be disabled
contract.merge(UserContract.new(age: 26))
contract.merge(other, strict: false)   # skip schema_validate!
contract.merge(other, validate: false) # skip valid?

# dup creates a mutable copy with attribute setters enabled
mutable = contract.dup
mutable.read_only? # => false
mutable.age = 26

# mutate is like clone but with required arguments — the changed attributes must be explicitly provided
# Calls schema_validate! internally; raises ApiContract::MissingAttributeError if required attrs are absent
mutable.mutate(name: "Jimmy")
```

The mutation surface is deliberately narrow. `dup` is the escape hatch to mutable state; `clone` and `merge` restore immutability. This prevents accidental state drift when contracts are passed across service boundaries.

**Note:** `clone` and `mutate` call `schema_validate!` internally. If a mutable contract has required attributes set to nil, `clone` or `mutate` will raise `ApiContract::MissingAttributeError`.

**`merge` behavior:** `merge` uses `deep_merge` under the hood — nested contracts are merged recursively, not replaced wholesale. The argument's values always win on conflict, including `nil`. A `nil` value in the argument will overwrite a populated value in the receiver. By default, `merge` calls both `schema_validate!` (`strict: true`) and `valid?` (`validate: true`) on the result; either can be disabled via keyword arguments when you need partial or intermediate states.

## Validation and Normalizers

Contracts support the full ActiveModel Validations and Normalizers API:

```ruby
class AddressContract < ApplicationContract
  attribute :state, :string

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :state, inclusion: { in: CUSTOMER_STATES }
  validates :postal_code, format: /\A\d{5}(-\d{4})?\z/

  after_validation :normalize_coordinates

  private

  def normalize_coordinates
    coordinates = Geocoder.coordinates(values.join(" "))
    self.latitude  = coordinates[0] if coordinates.present?
    self.longitude = coordinates[1] if coordinates.present?
  end
end
```

ActiveModel callbacks (`before_validation`, `after_validation`, etc.) are supported. This is particularly useful for derived attributes like geocoded coordinates that depend on other fields being valid first.

Nested contract validations run recursively. A parent contract is only valid when all nested contracts are also valid. Nested errors are propagated to the parent's error hash with flattened dot-notation keys:

```ruby
contract = UserContract.new(attrs)
contract.valid?
contract.errors
# => {
#   :"home_address.city"        => ["can't be blank"],
#   :"home_address.postal_code" => ["is invalid"]
# }
```

## Default Values

A `default:` suppresses `MissingAttributeError` and is applied when the attribute is absent or explicitly `nil`:

```ruby
class ApiErrorResponseContract < ApiErrorContract
  attribute :code,   :string,  default: "001"
  attribute :status, :integer, default: 422
end

contract = ApiErrorResponseContract.new({})
contract.code   # => "001"
contract.status # => 422

contract = ApiErrorResponseContract.new(code: nil)
contract.code   # => "001"
```

Subclasses can override default values by re-declaring the attribute:

```ruby
class ApiErrorContract < ApplicationContract
  attribute :code, :string, default: "000"
end

class ApiErrorResponseContract < ApiErrorContract
  attribute :code, :string, default: "001"  # overrides parent default
end
```

## Nested Contracts

Reference nested contracts by class or by string (resolved at runtime):

```ruby
class UserContract < ApplicationContract
  attribute :home_address, contract: 'AddressContract'
end
```

String references allow forward declarations and reduce load-order coupling. Resolution is performed at runtime and memoized in a thread-safe manner, making string references safe to use under concurrent Rails requests.

### Polymorphic Nesting with `one_of`

When a nested attribute may match one of several contract shapes, use `one_of`:

```ruby
class UserContract < ApplicationContract
  # Required; must match one of the listed contracts
  attribute :home_address, contract: one_of('USAddressContract', 'UKAddressContract')

  # Optional; must match if present
  attribute :shipping_address, contract: one_of('USAddressContract', 'UKAddressContract'), optional: true

  # Required; tries each contract in order, falls back to accepting any hash
  attribute :billing_address, contract: one_of('USAddressContract', 'UKAddressContract'), permissive: true

  # Optional; tries each contract, falls back to any hash
  attribute :other_address, contract: one_of('USAddressContract', 'UKAddressContract'), permissive: true, optional: true
end
```

Deserialization attempts each contract in declaration order using the following algorithm:

1. Instantiate the candidate contract with `.new` — which never raises
2. Call `schema_validate!` on the result
3. If `schema_validate!` raises, move to the next candidate
4. If `schema_validate!` does not raise, return that contract

If no candidate passes `schema_validate!` and `permissive: true` is not set, `ApiContract::UnexpectedAttributeError` is raised.

## Types Reference

### Standard Types (via ActiveModel::Attributes)

`big_integer`, `binary`, `boolean`, `date`, `date_time`, `decimal`, `float`, `immutable_string`, `integer`, `string`, `time`, `value`

### Special Types

**`:permissive_hash`** — Accepts any hash with any keys. Serializes to a JSON object. Deserializes to a `Hash` with symbolized keys. "Permissive" refers to the hash contents — any keys and values are allowed — not to the value itself. A `nil` value is not a valid hash, so `nil` is rejected unless the attribute is declared `optional: true`.

**`array: :type`** — Typed array. Elements are coerced using standard ActiveModel casting rules — `"100"` coerces to `100` for an `:integer` array. However, values that ActiveModel would silently cast to a fallback (e.g., `"a"` → `0`) must instead raise `ApiContract::InvalidContractError`. The gem must override ActiveModel's default silent-fallback behavior for typed arrays so that only genuinely coercible values are accepted. Non-array values (including `nil`) are rejected unless the attribute is declared `optional: true`.

**`array: :permissive`** — Accepts any array including nested hashes and nils. "Permissive" refers to the array elements — any types are allowed — not to the value itself. No element coercion or validation. Serializes to a JSON array. Non-array values (including `nil`) are rejected unless the attribute is declared `optional: true`.

**`contract:`** — Nested contract, with recursive validation.

**`:computed`** — Derived value produced at serialization time. Never read from input; never raises `MissingAttributeError`. See [Computed Attributes](#computed-attributes).

## Computed Attributes

A computed attribute is not read from input and plays no role in structural or data validation. Its value is produced at serialization time by calling a block or instance method on the contract. The result appears in `to_h`, `as_json`, `to_json`, and `as_camelcase_json` under the declared attribute key.

```ruby
# Using a block
attribute :coordinates, :computed, with: -> { [latitude, longitude] }

# Using a method name
attribute :coordinates, :computed, :build_coordinates
```

Because the block or method is called on the contract instance, it has full access to all other attribute values via their reader methods.

Computed attributes:
- Are **excluded from deserialization** — they are silently ignored if present in `from_params` or `from_json` input
- Are **excluded from `attributes`** and **excluded from `valid?` / `errors`** — they cannot be the source of a validation failure
- Are **always optional** — a nil return value is serialized as `null` unless `compact` is used
- **Do appear in `open_api_schema`** with `"readOnly": true` since they are output-only

### Extended Example

A common use case is assembling derived or formatted values from other attributes without storing them on the model:

```ruby
class AddressContract < ApplicationContract
  attribute :street,      array: :string, description: "Street lines"
  attribute :city,        :string,        description: "City"
  attribute :state,       :string,        description: "2-letter state abbreviation"
  attribute :postal_code, :string,        description: "ZIP code"
  attribute :latitude,    :float,         description: "Latitude",  optional: true
  attribute :longitude,   :float,         description: "Longitude", optional: true

  # Assembled at serialization from the stored lat/lng attributes
  attribute :coordinates, :computed, with: -> { [latitude, longitude].all?(&:present?) ? [latitude, longitude] : nil }

  # Formatted single-line address assembled from structured fields
  attribute :full_address, :computed, :build_full_address

  validates :postal_code, format: /\A\d{5}(-\d{4})?\z/
  validates :state,       inclusion: { in: CUSTOMER_STATES }

  after_validation :geocode

  private

  def build_full_address
    parts = street + [city, "#{state} #{postal_code}"]
    parts.join(", ")
  end

  def geocode
    result = Geocoder.coordinates(build_full_address)
    return unless result.present?
    self.latitude  = result[0]
    self.longitude = result[1]
  end
end
```

```ruby
attrs = {
  street:      ["123 Main St", "Apt 4B"],
  city:        "Springfield",
  state:       "IL",
  postal_code: "62701"
}

contract = AddressContract.new(attrs)
contract.valid? # => true  (also runs geocode via after_validation)

contract.as_json
# => {
#   "street"       => ["123 Main St", "Apt 4B"],
#   "city"         => "Springfield",
#   "state"        => "IL",
#   "postal_code"  => "62701",
#   "latitude"     => 39.7990,
#   "longitude"    => -89.6544,
#   "coordinates"  => [39.7990, -89.6544],
#   "full_address" => "123 Main St, Apt 4B, Springfield, IL 62701"
# }

# Computed attributes are excluded from input — this does not raise UnexpectedAttributeError
AddressContract.from_params(params.merge(coordinates: [0, 0], full_address: "ignored"))
```

Note that `latitude` and `longitude` are regular optional attributes populated via the `after_validation` callback. `coordinates` is a computed attribute that reads from them at serialization time. This separation keeps the stored data flat and normalized while the serialized representation stays rich.

## Permissive Attributes

When a contract needs to accept and round-trip unknown keys alongside its declared schema, include `ApiContract::PermissiveAttributes`. Including this module also disables strict deserialization — `from_params` and `from_json` will no longer raise `UnexpectedAttributeError` for unknown keys, routing them to `permissive_attributes` instead. This is intentional: permissive contracts are used when payloads are flexible or partially unknown, and it is left to the implementor to define any custom validation logic for those extra attributes rather than having the contract reject them outright.

```ruby
class PermissiveHashContract < ApiContract::Base
  include ApiContract::PermissiveAttributes

  attribute :name, :string
  attribute :data, :permissive_hash
end

contract = PermissiveHashContract.new(name: "test", data: {}, foo: "bar")
contract.permissive?              # => true
contract.has_key?(:foo)           # => true
contract.has_attribute?(:foo)     # => false  (not part of the schema)
contract.attributes               # => [:name, :data]

contract.as_json                              # => { "name" => "test", "data" => {} }
contract.as_json(permissive: true)            # => { "name" => "test", "data" => {}, "foo" => "bar" }
contract.with_passthrough_attributes.to_h     # => { name: "test", data: {}, foo: "bar" }
contract.permissive_attributes                # => { foo: "bar" }
```

Unknown keys are stored separately from the schema. They are invisible by default and must be explicitly opted into via the `permissive: true` serialization option.

## OpenAPI Schema Generation

Every contract can generate a JSON Schema object describing its shape, types, and documentation. Because `description:` is a first-class attribute option, contracts are self-documenting by design — the schema reflects what developers already wrote, with no separate annotation layer.

```ruby
UserContract.open_api_schema
# => {
#   "type" => "object",
#   "required" => ["name", "email", "home_address", "favorite_foods"],
#   "properties" => {
#     "name"               => { "type" => "string",  "description" => "User's full name" },
#     "age"                => { "type" => "integer", "description" => "User's age" },
#     "email"              => { "type" => "string",  "description" => "Email address" },
#     "home_address"       => { "$ref" => "#/components/schemas/AddressContract" },
#     "health_information" => { "type" => "object",  "description" => "Any health information" },
#     "favorite_foods"     => { "type" => "array", "items" => { "type" => "string" }, "description" => "Favorite foods, max 3" }
#   }
# }
```

Optional attributes are omitted from the `required` array. Nested contracts emit a `$ref` to their own schema, enabling standard component reuse in OpenAPI documents.

### Custom Generator

`open_api_schema` returns a plain Ruby hash, so building a generator is straightforward:

```ruby
# config/initializers/openapi.rb
module OpenApi
  def self.generate
    contracts = [UserContract, AddressContract, ApiErrorResponseContract]

    schemas = contracts.each_with_object({}) do |contract, hash|
      hash[contract.name] = contract.open_api_schema
    end

    {
      "openapi" => "3.0.0",
      "info"    => { "title" => "My API", "version" => "1.0.0" },
      "components" => { "schemas" => schemas }
    }
  end
end
```

### RSwag Integration

[RSwag](https://github.com/rswag/rswag) generates OpenAPI documentation from RSpec request specs. Contracts integrate directly by providing the schema hash where RSwag expects an inline schema definition:

```ruby
# spec/requests/users_spec.rb
require 'swagger_helper'

RSpec.describe 'Users API', type: :request do
  path '/users' do
    post 'Creates a user' do
      consumes 'application/json'
      produces 'application/json'

      parameter name: :user, in: :body, schema: UserContract.open_api_schema

      response '201', 'user created' do
        schema UserResponseContract.open_api_schema
        # ...
      end

      response '422', 'invalid request' do
        schema ApiErrorResponseContract.open_api_schema
        # ...
      end
    end
  end
end
```

Because the schema is derived directly from the contract class used in the controller, request documentation and runtime enforcement are always in sync — changing an attribute in the contract updates both the validation behavior and the generated API docs.

## Exception Reference

### Schema-Level (raised by `schema_validate!`, and by `from_params` / `from_json` / `from_camelized_json` which call it internally)

| Exception | When |
|---|---|
| `ApiContract::MissingAttributeError` | One or more required attributes are absent. Checked before unexpected attributes. |
| `ApiContract::UnexpectedAttributeError` | Attributes are present that are not declared in the schema. |

### Data-Level

| Exception | When |
|---|---|
| `ApiContract::InvalidContractError` | Structural shape is correct but data fails validations or type coercion. Exposes a `#contract` method returning the original contract object; use `#errors` on it to retrieve validation messages. |

`InvalidContractError` is also raised by serialization methods (`to_json`, `as_json`, `as_camelcase_json`) when called on an invalid contract.

---

## Open Questions

1. **`one_of` resolution ambiguity** — ✅ Resolved. First match wins. Each candidate is instantiated with `.new` and then `schema_validate!` is called; the first candidate that does not raise is used. Declaration order is therefore significant — more specific contracts should be listed before more general ones.

2. **`merge` conflict resolution** — ✅ Resolved. `merge` uses `deep_merge` so the argument always wins, including `nil` values — a `nil` in the argument will overwrite a populated value in the receiver. Schema and data validation are both run on the result by default but can each be disabled independently via `strict: false` and `validate: false`.

3. **Nested contract errors in the parent's error hash** — ✅ Resolved. Error keys are flattened using dot notation (e.g., `errors[:"home_address.city"]`). There is no nesting in the error hash.

4. **`mutate` vs `clone` distinction** — ✅ Resolved. `clone` accepts optional keyword arguments — you can provide as many or as few changed attributes as you like. `mutate` requires that the changed attributes be explicitly provided as arguments; it will not accept an empty call. Both return a new immutable contract and call `schema_validate!` internally.

5. **Array element type coercion errors** — ✅ Resolved. Standard ActiveModel coercion applies where the cast is meaningful — `"100"` coerces to `100` for an `:integer` array. Values that ActiveModel would silently fall back on (e.g., `"a"` → `0`) must raise `ApiContract::InvalidContractError` instead. The gem must intercept ActiveModel's silent-fallback path for typed arrays and treat those cases as data-level errors.

6. **Thread safety of string-referenced contracts** — ✅ Resolved. String-referenced contract resolution is memoized and must be implemented in a thread-safe manner. The gem must ensure that concurrent Rails requests resolving the same string reference do not produce race conditions — for example, by using `Mutex` or Ruby's `||=` under a class-level lock rather than a bare instance variable assignment.

7. **`to_params` behavior on nested contracts** — ✅ Resolved. `to_params` must produce a structure that is indistinguishable from what Rails would generate natively — nested contracts become nested `ActionController::Parameters` objects, preserving the full depth of the structure. The gem must not flatten or transform the hierarchy, as doing so would break any downstream code that traverses or permits nested params in the standard Rails way.

8. **`open_api_schema` and `one_of`** — Does `open_api_schema` emit a JSON Schema `oneOf` construct for polymorphic nested contracts, or does it produce something simpler?