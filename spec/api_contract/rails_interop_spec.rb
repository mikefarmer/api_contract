# frozen_string_literal: true

require 'action_controller'

RSpec.describe ApiContract::RailsInterop do
  before do
    address_klass = Class.new(ApiContract::Base) do
      attribute :street_name, :string
      attribute :zip_code, :string
    end
    stub_const('RailsInteropAddress', address_klass)

    klass = Class.new(ApiContract::Base) do
      attribute :first_name, :string
      attribute :last_name, :string
      attribute :home_address, contract: 'RailsInteropAddress', optional: true
    end
    stub_const('RailsInteropUser', klass)
  end

  describe '.from_camelized_json' do
    it 'converts camelCase keys to snake_case' do
      json = '{"firstName":"Alice","lastName":"Smith"}'
      contract = RailsInteropUser.from_camelized_json(json)
      expect(contract.first_name).to eq('Alice')
    end

    it 'handles nested camelCase keys' do
      json = '{"firstName":"Alice","lastName":"Smith","homeAddress":{"streetName":"Main St","zipCode":"12345"}}'
      contract = RailsInteropUser.from_camelized_json(json)
      expect(contract.home_address.street_name).to eq('Main St')
    end

    it 'round-trips with as_camelcase_json' do
      json = '{"firstName":"Alice","lastName":"Smith"}'
      contract = RailsInteropUser.from_camelized_json(json)
      expect(contract.as_camelcase_json['firstName']).to eq('Alice')
    end

    it 'raises MissingAttributeError for missing required keys' do
      json = '{"firstName":"Alice"}'
      expect { RailsInteropUser.from_camelized_json(json) }
        .to raise_error(ApiContract::MissingAttributeError)
    end

    it 'raises JSON::ParserError for invalid JSON' do
      expect { RailsInteropUser.from_camelized_json('not json') }
        .to raise_error(JSON::ParserError)
    end
  end

  describe '#to_params' do
    it 'returns an ActionController::Parameters instance' do
      contract = RailsInteropUser.new(first_name: 'Alice', last_name: 'Smith')
      expect(contract.to_params).to be_a(ActionController::Parameters)
    end

    it 'contains string-keyed attributes' do
      contract = RailsInteropUser.new(first_name: 'Alice', last_name: 'Smith')
      expect(contract.to_params['first_name']).to eq('Alice')
    end

    it 'is pre-permitted when schema-valid' do
      contract = RailsInteropUser.new(first_name: 'Alice', last_name: 'Smith')
      expect(contract.to_params.permitted?).to be true
    end

    it 'is not permitted when schema-invalid' do
      invalid = RailsInteropUser.new(first_name: 'Alice')
      expect(invalid.to_params.permitted?).to be false
    end

    it 'converts nested contracts to nested parameters' do
      contract = RailsInteropUser.new(
        first_name: 'Alice', last_name: 'Smith',
        home_address: { street_name: 'Main St', zip_code: '12345' }
      )
      expect(contract.to_params['home_address']).to be_a(ActionController::Parameters)
    end

    it 'preserves nested values' do
      contract = RailsInteropUser.new(
        first_name: 'Alice', last_name: 'Smith',
        home_address: { street_name: 'Main St', zip_code: '12345' }
      )
      expect(contract.to_params['home_address']['street_name']).to eq('Main St')
    end
  end
end
