# ApiContract Gem - Implementation Progress

## Current State

The gem has solid foundational architecture. Core contract definition, schema validation, type coercion (including strict coercion that catches ActiveModel silent fallbacks), typed/permissive arrays, and permissive hashes are implemented and thoroughly tested.

### Completed

- Attribute DSL (`attribute` with type, optional, default, description, array)
- Schema validation (`schema_valid?`, `schema_errors`, `schema_validate!`)
- `.new` (never raises), `.from_params`, `.from_json`
- Strict coercion validation (catches silent fallbacks like `"a"` -> `0`)
- Typed arrays (`array: :string`, `array: :integer`, etc.)
- Permissive arrays (`array: :permissive`)
- Permissive hash type (`:permissive_hash` with deep key symbolization)
- Error classes (`MissingAttributeError`, `UnexpectedAttributeError`, `InvalidContractError`)
- Inheritance with deep-copied attribute registry
- CI workflow (RuboCop + RSpec)
- SimpleCov coverage tracking
- **Phase 1: Serialization** — `to_h`, `as_json`, `to_json`, `as_camelcase_json`, `attributes`, `values`, `dig` (extracted into `ApiContract::Serialization` module)
- **Phase 2: Immutability & Mutation** — `read_only?`, frozen writers, `clone`, `dup`, `mutate`, `merge` (extracted into `ApiContract::Immutability` module)
- **Phase 3: Normalizers & Callbacks** — Custom `normalizes` DSL, verified `before_validation`/`after_validation` callbacks (extracted into `ApiContract::Normalizers` module)
- **Phase 4: Nested Contracts** — `contract:` option with class/string references, thread-safe resolution, recursive schema validation, dot-notation error propagation, deep key serialization (extracted into `ApiContract::NestedContract` and `ApiContract::SchemaValidation` modules)
- **Phase 5: Polymorphic Nesting** — `one_of` descriptor, first-match-wins resolution, `permissive:` fallback, optional nil support (`ApiContract::OneOf`)
- **Phase 6: Computed Attributes** — `:computed` type with lambda/method forms, excluded from deserialization and schema validation, included in serialization (`ApiContract::Computed`)
- **Phase 7: Permissive Attributes** — `PermissiveAttributes` mixin with `key?`/`declared_attribute?` (aliased as `has_key?`/`has_attribute?`), `permissive_attributes`, `with_passthrough_attributes`, `as_json(permissive: true)`, disabled strict deserialization, schema override (`ApiContract::PermissiveAttributes`)
- **Phase 8: Rails Interop** — `from_camelized_json` (camelCase→snake_case deserialization), `to_params` (pre-permitted `ActionController::Parameters` with nested contract support) (`ApiContract::RailsInterop`)
- **Phase 9: OpenAPI Schema** — `.open_api_schema` class method generating JSON Schema / OpenAPI 3.0 hashes with type mapping, `$ref` for nested contracts, `oneOf` for polymorphic, `readOnly` for computed, array items, permissive hash (`ApiContract::OpenApiSchema`)
- **Phase 10: YARD Documentation** — 100% YARD coverage, generated HTML docs committed to `doc/`
- **Phase 11: Integration Testing** — Full lifecycle integration tests covering construction, validation, serialization, camelCase round-trip, immutability, `to_params`, and OpenAPI schema generation (382 total tests, 98.84% line coverage)

---

## Remaining Work

### Phase 1: Serialization

Implement all serialization and traversal methods on `ApiContract::Base`.

**Files:** `lib/api_contract/base.rb`, `spec/api_contract/base_spec.rb`

1. **`#to_h`** - Return a symbolized hash of all declared attributes and their values. Optional attributes with nil values are excluded.
2. **`#as_json`** - Return a string-keyed hash. Raise `InvalidContractError` if `valid?` returns false.
3. **`#to_json`** - JSON string via `as_json`. Raise `InvalidContractError` if invalid.
4. **`#as_camelcase_json`** - Like `as_json` but keys converted to camelCase. Raise `InvalidContractError` if invalid.
5. **`#attributes`** - Return array of declared attribute names (symbols).
6. **`#values`** - Return array of attribute values in declaration order.
7. **`#dig(*keys)`** - Delegate to `to_h.dig`.

**Tests:** Each method gets positive and negative cases, including InvalidContractError raising behavior.

---

### Phase 2: Immutability & Mutation

Make contracts immutable by default with controlled mutation paths.

**Files:** `lib/api_contract/base.rb`, `spec/api_contract/immutability_spec.rb`

1. **`#read_only?`** - Returns `true` for contracts created via `.new`, `.from_params`, `.from_json`. Returns `false` for `#dup`-ed contracts.
2. **Freeze attribute writers** - Attribute setters raise when `read_only?` is true.
3. **`#clone(**changes)`** - Return a new immutable contract with changed attributes merged. Calls `schema_validate!` internally.
4. **`#dup`** - Return a mutable copy with attribute setters enabled. `read_only?` returns false.
5. **`#mutate(**changes)`** - Like `clone` but requires at least one changed attribute. Calls `schema_validate!`.
6. **`#merge(other, strict: true, validate: true)`** - Deep merge another contract into the receiver, returning a new immutable contract. Argument wins on conflict (including nil). Optionally skip `schema_validate!` (`strict: false`) or `valid?` (`validate: false`).

**Tests:** Immutability enforcement, clone/dup/mutate/merge behaviors, error raising on frozen writes.

---

### Phase 3: Normalizers & Callbacks

Wire up ActiveModel normalizers and verify callback support.

**Files:** `lib/api_contract/base.rb`, `spec/api_contract/normalizers_spec.rb`

1. **`normalizes`** - Expose the ActiveModel `normalizes` DSL. Normalizers run during initialization after type coercion.
2. **Callback verification** - Verify `before_validation`, `after_validation`, and other ActiveModel callbacks work correctly within contracts. Add integration tests.

**Tests:** Normalizer transforms values, callbacks fire in correct order, normalizers + callbacks interact correctly.

---

### Phase 4: Nested Contracts

Support `contract:` attribute option for nested contract composition.

**Files:** `lib/api_contract/attribute_registry.rb`, `lib/api_contract/base.rb`, `lib/api_contract/nested_contract.rb` (new), `spec/api_contract/nested_contract_spec.rb`

1. **`contract:` option** - Accept a class or string reference. String references resolved at runtime and memoized thread-safely (Mutex or similar).
2. **Nested instantiation** - When constructing a contract, nested hash values are automatically instantiated as the referenced contract class.
3. **Recursive schema validation** - `schema_validate!` recurses into nested contracts.
4. **Nested error propagation** - Nested validation errors are flattened into the parent error hash with dot-notation keys (e.g., `:"home_address.city"`).
5. **Nested serialization** - `to_h`, `as_json`, `to_json`, `as_camelcase_json` all recurse into nested contracts.
6. **`from_params` / `from_json` nesting** - Nested hashes in input are deserialized into nested contract instances.

**Tests:** String and class references, thread-safe resolution, recursive validation, dot-notation errors, nested serialization round-trip.

---

### Phase 5: Polymorphic Nesting (`one_of`)

Support `one_of` for polymorphic nested contracts.

**Files:** `lib/api_contract/one_of.rb` (new), `lib/api_contract/base.rb`, `spec/api_contract/one_of_spec.rb`

1. **`one_of(*contracts)`** class method - Returns a descriptor used by the `contract:` option.
2. **Resolution algorithm** - Instantiate each candidate with `.new`, call `schema_validate!`, return first that passes. If none pass and `permissive: true`, accept as plain hash. If none pass without permissive, raise `UnexpectedAttributeError`.
3. **`optional: true` + `one_of`** - Nil is accepted when optional.
4. **`permissive: true` + `one_of`** - Falls back to accepting any hash when no candidate matches.

**Tests:** First-match-wins ordering, permissive fallback, optional nil, error on no match.

---

### Phase 6: Computed Attributes

Support `:computed` type for derived values produced at serialization time.

**Files:** `lib/api_contract/computed.rb` (new), `lib/api_contract/attribute_registry.rb`, `lib/api_contract/base.rb`, `spec/api_contract/computed_spec.rb`

1. **`:computed` type with `with:` option** - Accepts a lambda or method name symbol.
2. **Excluded from deserialization** - Silently ignored if present in `from_params` or `from_json` input; never causes `UnexpectedAttributeError`.
3. **Excluded from schema validation** - Never raises `MissingAttributeError`, excluded from `attributes` list and `valid?`/`errors`.
4. **Included in serialization** - `to_h`, `as_json`, `to_json`, `as_camelcase_json` include computed values.
5. **Block has access to contract instance** - Lambda or method executes in the context of the contract, accessing other attributes via reader methods.

**Tests:** Block and method-name forms, exclusion from input/validation, inclusion in serialization, nil handling.

---

### Phase 7: Permissive Attributes Module

Implement `ApiContract::PermissiveAttributes` mixin for round-tripping unknown keys.

**Files:** `lib/api_contract/permissive_attributes.rb` (new), `spec/api_contract/permissive_attributes_spec.rb`

1. **`include ApiContract::PermissiveAttributes`** - Module that stores unknown keys separately from declared attributes.
2. **`#permissive?`** - Returns true when the mixin is included.
3. **`#has_key?(key)`** - Checks both declared attributes and permissive attributes.
4. **`#has_attribute?(key)`** - Checks only declared attributes (schema).
5. **`#permissive_attributes`** - Returns hash of unknown keys/values.
6. **`#with_passthrough_attributes`** - Returns a wrapper/contract that includes permissive attributes in `to_h`.
7. **`#as_json(permissive: true)`** - Includes permissive attributes in JSON output.
8. **Disable strict deserialization** - `from_params` and `from_json` no longer raise `UnexpectedAttributeError` for unknown keys; they route to `permissive_attributes`.

**Tests:** Unknown key storage, serialization with/without permissive flag, `has_key?` vs `has_attribute?`, disabled strict deserialization.

---

### Phase 8: `from_camelized_json` & `to_params`

Implement remaining deserialization and Rails interop methods.

**Files:** `lib/api_contract/base.rb`, `spec/api_contract/serialization_spec.rb`

1. **`.from_camelized_json(json_string)`** - Convert camelCase keys to snake_case before deserialization. Mirrors `as_camelcase_json`.
2. **`#to_params`** - Return an `ActionController::Parameters` instance. Nested contracts become nested `ActionController::Parameters`. Pre-permitted when `schema_valid?`. Structure mirrors native Rails params.

**Tests:** Round-trip camelCase JSON, `to_params` with nested structures, `permitted?` status.

---

### Phase 9: OpenAPI Schema Generation

Generate JSON Schema from any contract.

**Files:** `lib/api_contract/open_api_schema.rb` (new), `spec/api_contract/open_api_schema_spec.rb`

1. **`.open_api_schema`** class method - Returns a hash conforming to JSON Schema / OpenAPI 3.0.
2. **Type mapping** - Map ActiveModel types to JSON Schema types (`string`, `integer`, `number`, `boolean`, `array`, `object`).
3. **Required array** - Non-optional attributes listed in `"required"`.
4. **Description** - `"description"` populated from attribute `description:` option.
5. **Nested contracts** - Emit `"$ref" => "#/components/schemas/ContractName"`.
6. **Computed attributes** - Include with `"readOnly": true`.
7. **`one_of` contracts** - Emit JSON Schema `"oneOf"` construct (addresses open question #8 from README).
8. **Array types** - Emit `"type": "array"` with `"items"` describing element type.
9. **Permissive hash** - Emit `"type": "object"` with no properties constraint.

**Tests:** Full schema output for contracts with all attribute types, nested refs, computed readOnly, oneOf, arrays.

---

### Phase 10: YARD Documentation Generation

Generate and commit YARD HTML documentation.

**Files:** `.yardopts` (new), `doc/` directory

1. **`.yardopts`** - Configure YARD output options (markup, output directory, files to include).
2. **Verify all public methods/classes have YARD docs** - Audit existing source for missing `@param`, `@return`, `@raise`, `@example` tags.
3. **Generate HTML docs** - Run `yard doc` and commit the output to the repository as specified in CLAUDE.md.

---

### Phase 11: Integration Testing & Documentation

End-to-end tests and usage documentation.

**Files:** `spec/api_contract/integration_spec.rb` (new)

1. **Full contract round-trip test** - Define realistic contracts (UserContract, AddressContract, etc.) and test the complete lifecycle: construction, validation, serialization, deserialization, mutation, nested contracts, computed attributes.
2. **Rails controller integration example** - Test `from_params` with realistic `ActionController::Parameters` input, `rescue_from` patterns, `to_params` round-trip.
3. **README accuracy audit** - Verify every code example in README.md works against the implementation. Fix any discrepancies.
