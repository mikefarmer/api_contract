# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-02-25

### Added

- **Core contract DSL** — `attribute` with type, `optional:`, `default:`, `description:`, `array:`, and `contract:` options
- **Schema validation** — `schema_valid?`, `schema_errors`, `schema_validate!` with `MissingAttributeError` and `UnexpectedAttributeError`
- **Strict type coercion** — catches ActiveModel silent fallbacks (e.g., `"a"` to `0`) and raises `InvalidContractError`
- **Typed arrays** (`array: :string`, `array: :integer`, etc.) and **permissive arrays** (`array: :permissive`)
- **Permissive hash type** (`:permissive_hash`) with deep key symbolization
- **Serialization** — `to_h`, `as_json`, `to_json`, `as_camelcase_json`, `attributes`, `values`, `dig`
- **Immutability** — contracts are read-only by default; controlled mutation via `clone`, `dup`, `mutate`, and `merge`
- **Normalizers and callbacks** — custom `normalizes` DSL, `before_validation`/`after_validation` callback support
- **Nested contracts** — `contract:` option with class or string references, thread-safe resolution, recursive validation, dot-notation error propagation
- **Polymorphic nesting** — `one_of` for matching against multiple contract shapes with first-match-wins resolution and `permissive:` fallback
- **Computed attributes** — `:computed` type with lambda/method forms, excluded from deserialization and validation, included in serialization
- **Permissive attributes module** — `ApiContract::PermissiveAttributes` mixin for round-tripping unknown keys alongside declared schema
- **Rails interop** — `from_params`, `from_json`, `from_camelized_json` (camelCase to snake_case), `to_params` (pre-permitted `ActionController::Parameters`)
- **OpenAPI schema generation** — `.open_api_schema` class method producing JSON Schema / OpenAPI 3.0 with `$ref`, `oneOf`, `readOnly`, and full type mapping
- **100% YARD documentation** on all public methods and classes
- **382 tests** with 98.84% line coverage
- **CI workflow** with RuboCop and RSpec
