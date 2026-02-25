# frozen_string_literal: true

require_relative 'lib/api_contract/version'

Gem::Specification.new do |spec|
  spec.name = 'api_contract'
  spec.version = ApiContract::VERSION
  spec.authors = ['Mike Farmer']
  spec.license = 'MIT'

  spec.summary = 'Typed, validated, immutable DTOs with Rails integration'
  spec.description = 'A Ruby gem for defining typed, validated, immutable data transfer objects (DTOs) ' \
                     'with first-class Rails integration. Drop-in replacement for StrongParameters ' \
                     'with type coercion, structural validation, and OpenAPI schema generation.'
  spec.homepage = 'https://github.com/turbo/api_contract'
  spec.required_ruby_version = '>= 3.4.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?('bin/', 'spec/', '.', 'Gemfile', 'Rakefile', 'ai/', 'doc/', 'mise.toml') ||
        f == 'CLAUDE.md'
    end
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'activemodel', '~> 7.1'
end
