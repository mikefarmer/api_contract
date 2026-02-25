# frozen_string_literal: true

RSpec.describe ApiContract::OpenApiSchema do
  before do
    addr = Class.new(ApiContract::Base) do
      attribute :street, :string, description: 'Street address'
      attribute :city, :string
    end
    stub_const('SchemaAddress', addr)

    klass = Class.new(ApiContract::Base) do
      attribute :name, :string, description: 'Full name'
      attribute :age, :integer, optional: true
      attribute :score, :float
      attribute :active, :boolean, default: true
      attribute :tags, array: :string
      attribute :data, :permissive_hash, optional: true
      attribute :home_address, contract: 'SchemaAddress', optional: true
      attribute :full_name, :computed, -> { name }
    end
    stub_const('SchemaUser', klass)
  end

  describe '.open_api_schema' do
    subject(:schema) { SchemaUser.open_api_schema }

    it 'returns an object type' do
      expect(schema['type']).to eq('object')
    end

    it 'maps string attributes' do
      expect(schema['properties']['name']).to include('type' => 'string')
    end

    it 'maps integer attributes' do
      expect(schema['properties']['age']).to include('type' => 'integer')
    end

    it 'maps float attributes to number' do
      expect(schema['properties']['score']).to include('type' => 'number')
    end

    it 'maps boolean attributes' do
      expect(schema['properties']['active']).to include('type' => 'boolean')
    end

    it 'includes description when present' do
      expect(schema['properties']['name']['description']).to eq('Full name')
    end

    it 'omits description when absent' do
      expect(schema['properties']['age']).not_to have_key('description')
    end

    it 'lists required attributes' do
      expect(schema['required']).to include('name', 'score')
    end

    it 'excludes optional attributes from required' do
      expect(schema['required']).not_to include('age')
    end

    it 'excludes attributes with defaults from required' do
      expect(schema['required']).not_to include('active')
    end

    it 'maps array attributes' do
      prop = schema['properties']['tags']
      expect(prop).to eq('type' => 'array', 'items' => { 'type' => 'string' })
    end

    it 'maps permissive_hash to object' do
      expect(schema['properties']['data']).to eq('type' => 'object')
    end

    it 'maps nested contracts to $ref' do
      prop = schema['properties']['home_address']
      expect(prop).to eq('$ref' => '#/components/schemas/SchemaAddress')
    end

    it 'marks computed attributes as readOnly' do
      expect(schema['properties']['full_name']['readOnly']).to be true
    end
  end

  describe 'nested contract schema' do
    it 'includes description on nested contract attributes' do
      schema = SchemaAddress.open_api_schema
      expect(schema['properties']['street']['description']).to eq('Street address')
    end
  end

  describe 'one_of schema' do
    before do
      us = Class.new(ApiContract::Base) { attribute :zip, :string }
      uk = Class.new(ApiContract::Base) { attribute :postcode, :string }
      stub_const('USAddr', us)
      stub_const('UKAddr', uk)

      poly = Class.new(ApiContract::Base) do
        attribute :name, :string
        attribute :address, contract: one_of('USAddr', 'UKAddr'), optional: true
      end
      stub_const('PolyContract', poly)
    end

    it 'emits oneOf construct for polymorphic attributes' do
      refs = PolyContract.open_api_schema.dig('properties', 'address', 'oneOf')
      expect(refs).to eq([{ '$ref' => '#/components/schemas/USAddr' }, { '$ref' => '#/components/schemas/UKAddr' }])
    end
  end
end
