# frozen_string_literal: true

require 'action_controller'

RSpec.describe ApiContract::Base do # rubocop:disable RSpec/SpecFilePathFormat
  before do
    address = Class.new(ApiContract::Base) do
      attribute :street, :string, description: 'Street address'
      attribute :city, :string
      attribute :state, :string
      attribute :zip, :string

      normalizes :state, with: :upcase.to_proc
      validates :state, length: { is: 2 }
    end
    stub_const('IntAddressContract', address)

    user = Class.new(ApiContract::Base) do
      attribute :name, :string, description: "User's full name"
      attribute :email, :string
      attribute :age, :integer, optional: true
      attribute :home_address, contract: 'IntAddressContract'
      attribute :tags, array: :string, optional: true
      attribute :data, :permissive_hash, optional: true
      attribute :full_name, :computed, -> { "Computed: #{name}" }

      normalizes :email, with: ->(e) { e.strip.downcase }
    end
    stub_const('IntUserContract', user)
  end

  let(:valid_params) do
    {
      name: 'Alice', email: 'alice@test.com',
      home_address: { street: '1 St', city: 'NY', state: 'NY', zip: '10001' }
    }
  end

  describe 'construction and validation' do
    it 'constructs a valid nested contract via .new' do
      c = IntUserContract.new(valid_params.merge(email: ' ALICE@TEST.COM '))
      expect(c.schema_valid?).to be true
    end

    it 'normalizes values during construction' do
      c = IntUserContract.new(valid_params.merge(email: ' ALICE@TEST.COM '))
      expect(c.email).to eq('alice@test.com')
    end

    it 'normalizes nested contract values' do
      c = IntUserContract.new(valid_params.merge(home_address: { street: '1', city: 'NY', state: 'ny', zip: '1' }))
      expect(c.home_address.state).to eq('NY')
    end

    it 'reports nested validation errors with dot notation' do
      c = IntUserContract.new(valid_params.merge(home_address: { street: '1', city: 'NY', state: 'toolong', zip: '1' }))
      c.valid?
      expect(c.errors[:'home_address.state']).to be_present
    end
  end

  describe 'from_params round-trip' do
    it 'deserializes and reserializes correctly' do
      c = IntUserContract.from_params(valid_params)
      expect(c.to_h[:name]).to eq('Alice')
    end

    it 'raises MissingAttributeError for missing required attrs' do
      expect { IntUserContract.from_params(name: 'Bob') }
        .to raise_error(ApiContract::MissingAttributeError)
    end

    it 'raises UnexpectedAttributeError for extra attrs' do
      expect { IntUserContract.from_params(valid_params.merge(unknown: 'x')) }
        .to raise_error(ApiContract::UnexpectedAttributeError)
    end
  end

  describe 'serialization' do
    let(:contract) { IntUserContract.from_params(valid_params) }

    it 'includes computed attributes in to_h' do
      expect(contract.to_h[:full_name]).to eq('Computed: Alice')
    end

    it 'serializes to camelCase JSON' do
      expect(contract.as_camelcase_json['homeAddress']).to be_a(Hash)
    end

    it 'round-trips through JSON' do
      expect(JSON.parse(contract.to_json)['name']).to eq('Alice')
    end
  end

  describe 'from_camelized_json round-trip' do
    it 'deserializes camelCase and round-trips to camelCase' do
      json = '{"name":"Eve","email":"eve@t.com","homeAddress":{"street":"9","city":"SF","state":"CA","zip":"94101"}}'
      c = IntUserContract.from_camelized_json(json)
      expect(c.as_camelcase_json['homeAddress']['city']).to eq('SF')
    end
  end

  describe 'immutability and mutation' do
    let(:contract) { IntUserContract.from_params(valid_params) }

    it 'is read-only after construction' do
      expect(contract.read_only?).to be true
    end

    it 'creates an immutable clone with changes' do
      expect(contract.clone(name: 'Bob').name).to eq('Bob')
    end

    it 'preserves immutability after clone' do
      expect(contract.clone(name: 'Bob').read_only?).to be true
    end
  end

  describe 'to_params interop' do
    it 'returns pre-permitted ActionController::Parameters' do
      c = IntUserContract.from_params(valid_params)
      expect(c.to_params.permitted?).to be true
    end
  end

  describe 'OpenAPI schema generation' do
    it 'generates a valid schema with nested $ref' do
      ref = IntUserContract.open_api_schema.dig('properties', 'home_address', '$ref')
      expect(ref).to include('IntAddressContract')
    end

    it 'marks computed attributes as readOnly' do
      expect(IntUserContract.open_api_schema.dig('properties', 'full_name', 'readOnly')).to be true
    end
  end
end
