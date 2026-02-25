# frozen_string_literal: true

RSpec.describe ApiContract::OneOf do
  before do
    stub_const('USAddressContract', us_address_class)
    stub_const('UKAddressContract', uk_address_class)
    stub_const('LocationContract', location_class)
  end

  let(:us_address_class) do
    Class.new(ApiContract::Base) do
      attribute :street, :string
      attribute :state, :string
      attribute :zip, :string
    end
  end

  let(:uk_address_class) do
    Class.new(ApiContract::Base) do
      attribute :street, :string
      attribute :county, :string
      attribute :postcode, :string
    end
  end

  let(:location_class) do
    Class.new(ApiContract::Base) do
      attribute :name, :string
      attribute :address, contract: ApiContract::Base.one_of('USAddressContract', 'UKAddressContract')
    end
  end

  describe 'first-match-wins ordering' do
    it 'resolves to the first matching contract' do
      attrs = { name: 'HQ', address: { street: '123 Main', state: 'NY', zip: '10001' } }
      contract = location_class.new(attrs)
      expect(contract.address).to be_a(us_address_class)
    end

    it 'resolves to second contract when first does not match' do
      attrs = { name: 'London', address: { street: '10 Downing', county: 'Westminster', postcode: 'SW1A' } }
      contract = location_class.new(attrs)
      expect(contract.address).to be_a(uk_address_class)
    end
  end

  describe 'no match raises error' do
    it 'raises UnexpectedAttributeError when no candidate matches' do
      attrs = { name: 'X', address: { lat: 0, lng: 0 } }
      expect { location_class.new(attrs) }.to raise_error(ApiContract::UnexpectedAttributeError, /one_of/)
    end
  end

  describe 'optional: true + one_of' do
    let(:optional_class) do
      klass = Class.new(ApiContract::Base) do
        attribute :name, :string
        attribute :address, contract: ApiContract::Base.one_of('USAddressContract', 'UKAddressContract'), optional: true
      end
      stub_const('OptionalOneOfContract', klass)
    end

    it 'accepts nil when optional' do
      contract = optional_class.new(name: 'Test')
      expect(contract.address).to be_nil
    end

    it 'resolves when present' do
      attrs = { name: 'T', address: { street: 'A', state: 'NY', zip: '1' } }
      contract = optional_class.new(attrs)
      expect(contract.address).to be_a(us_address_class)
    end
  end

  describe 'permissive: true + one_of' do
    let(:permissive_class) do
      klass = Class.new(ApiContract::Base) do
        attribute :name, :string
        attribute :address,
                  contract: ApiContract::Base.one_of('USAddressContract', 'UKAddressContract'),
                  permissive: true
      end
      stub_const('PermissiveOneOfContract', klass)
    end

    it 'falls back to plain hash when no candidate matches' do
      attrs = { name: 'X', address: { lat: 0, lng: 0 } }
      contract = permissive_class.new(attrs)
      expect(contract.address).to eq(lat: 0, lng: 0)
    end

    it 'resolves to contract when a candidate matches' do
      attrs = { name: 'T', address: { street: 'A', state: 'NY', zip: '1' } }
      contract = permissive_class.new(attrs)
      expect(contract.address).to be_a(us_address_class)
    end
  end

  describe 'serialization with one_of' do
    it 'serializes matched nested contract in to_h' do
      attrs = { name: 'HQ', address: { street: '123', state: 'NY', zip: '10001' } }
      contract = location_class.new(attrs)
      expect(contract.to_h[:address]).to eq(street: '123', state: 'NY', zip: '10001')
    end
  end

  describe 'from_params / from_json with one_of' do
    it 'from_params resolves one_of contracts' do
      attrs = { name: 'HQ', address: { street: '123', state: 'NY', zip: '10001' } }
      contract = location_class.from_params(attrs)
      expect(contract.address).to be_a(us_address_class)
    end

    it 'from_json resolves one_of contracts' do
      json = '{"name":"HQ","address":{"street":"10","county":"W","postcode":"SW1"}}'
      contract = location_class.from_json(json)
      expect(contract.address).to be_a(uk_address_class)
    end
  end
end
