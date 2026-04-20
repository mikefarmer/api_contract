# frozen_string_literal: true

RSpec.describe 'ApiContract::Base array-of-contracts attributes' do
  before do
    stub_const('AddressContract', address_class)
    stub_const('UserContract', user_class)
  end

  let(:address_class) do
    Class.new(ApiContract::Base) do
      attribute :city, :string
      attribute :state, :string

      validates :state, length: { is: 2 }
    end
  end

  let(:user_class) do
    Class.new(ApiContract::Base) do
      attribute :name, :string
      attribute :addresses, array: 'AddressContract'
    end
  end

  describe 'registry metadata' do
    it 'records :contract_array as the attribute type' do
      expect(user_class.attribute_registry[:addresses][:type]).to eq(:contract_array)
    end

    it 'stores the contract reference' do
      expect(user_class.attribute_registry[:addresses][:contract]).to eq('AddressContract')
    end

    it 'marks the attribute as required by default' do
      expect(user_class.required_attribute_names).to include(:addresses)
    end
  end

  describe 'instantiation from hashes' do
    it 'converts array elements to contract instances' do
      contract = user_class.new(name: 'Alice', addresses: [{ city: 'NYC', state: 'NY' }])
      expect(contract.addresses.first).to be_a(address_class)
    end

    it 'preserves multiple elements with their own values' do
      attrs = { name: 'Alice', addresses: [{ city: 'NYC', state: 'NY' }, { city: 'LA', state: 'CA' }] }
      contract = user_class.new(attrs)
      expect(contract.addresses.map(&:city)).to eq(%w[NYC LA])
    end

    it 'accepts an empty array' do
      contract = user_class.new(name: 'Alice', addresses: [])
      expect(contract.addresses).to eq([])
    end
  end

  describe 'class and symbol references' do
    let(:class_ref_class) do
      addr = address_class
      Class.new(ApiContract::Base) do
        attribute :name, :string
        attribute :addresses, array: addr
      end
    end

    it 'accepts a direct class reference' do
      contract = class_ref_class.new(name: 'Alice', addresses: [{ city: 'NYC', state: 'NY' }])
      expect(contract.addresses.first).to be_a(address_class)
    end
  end

  describe 'schema validation' do
    it 'is schema_valid? with all required elements present' do
      contract = user_class.new(name: 'Alice', addresses: [{ city: 'NYC', state: 'NY' }])
      expect(contract).to be_schema_valid
    end

    it 'raises MissingAttributeError for a missing nested key in an element' do
      contract = user_class.new(name: 'Alice', addresses: [{ city: 'NYC' }])
      expect { contract.schema_validate! }.to raise_error(ApiContract::MissingAttributeError, /state/)
    end

    it 'raises UnexpectedAttributeError for an unexpected nested key in an element' do
      contract = user_class.new(name: 'Alice', addresses: [{ city: 'NYC', state: 'NY', zip: 'x' }])
      expect { contract.schema_validate! }.to raise_error(ApiContract::UnexpectedAttributeError, /zip/)
    end

    it 'rejects non-array raw values via strict coercion' do
      contract = user_class.new(name: 'Alice', addresses: { city: 'NYC', state: 'NY' })
      contract.valid?
      expect(contract.errors[:addresses]).to include(match(/is not a valid array/))
    end

    it 'rejects array elements that are not hashes or contracts' do
      contract = user_class.new(name: 'Alice', addresses: [1, 'oops'])
      contract.valid?
      expect(contract.errors[:addresses]).to include(match(/is not a valid contract/))
    end
  end

  describe 'data validation error propagation' do
    it 'propagates element errors with indexed dot-notation keys' do
      attrs = { name: 'Alice', addresses: [{ city: 'NYC', state: 'NY' }, { city: 'LA', state: 'XYZ' }] }
      contract = user_class.new(attrs)
      contract.valid?
      expect(contract.errors[:'addresses[1].state']).to include(/is the wrong length/)
    end

    it 'is valid when every element is valid' do
      attrs = { name: 'Alice', addresses: [{ city: 'NYC', state: 'NY' }, { city: 'LA', state: 'CA' }] }
      expect(user_class.new(attrs)).to be_valid
    end

    it 'is invalid when any element fails validation' do
      attrs = { name: 'Alice', addresses: [{ city: 'NYC', state: 'NY' }, { city: 'LA', state: 'XYZ' }] }
      expect(user_class.new(attrs)).not_to be_valid
    end
  end

  describe 'optional and default handling' do
    let(:optional_class) do
      Class.new(ApiContract::Base) do
        attribute :name, :string
        attribute :addresses, array: 'AddressContract', optional: true
      end
    end

    let(:default_class) do
      Class.new(ApiContract::Base) do
        attribute :name, :string
        attribute :addresses, array: 'AddressContract', optional: true, default: []
      end
    end

    it 'allows nil when optional' do
      contract = optional_class.new(name: 'Alice')
      expect(contract.addresses).to be_nil
    end

    it 'applies default when absent' do
      expect(default_class.new(name: 'Alice').addresses).to eq([])
    end
  end

  describe 'serialization' do
    let(:contract) do
      user_class.new(
        name: 'Alice',
        addresses: [{ city: 'NYC', state: 'NY' }, { city: 'LA', state: 'CA' }]
      )
    end

    it '#to_h returns plain hashes for each element' do
      expect(contract.to_h[:addresses]).to eq([
                                                { city: 'NYC', state: 'NY' },
                                                { city: 'LA', state: 'CA' }
                                              ])
    end

    it '#as_json returns string-keyed hashes for each element' do
      expect(contract.as_json['addresses']).to eq([
                                                    { 'city' => 'NYC', 'state' => 'NY' },
                                                    { 'city' => 'LA', 'state' => 'CA' }
                                                  ])
    end

    it '#to_json round-trips' do
      parsed = JSON.parse(contract.to_json)
      expect(parsed['addresses'].first['city']).to eq('NYC')
    end

    context 'with camelCase nested keys' do
      before do
        stub_const('CamelAddressContract', Class.new(ApiContract::Base) do
          attribute :postal_code, :string
          attribute :street_name, :string
        end)
        stub_const('CamelUserContract', Class.new(ApiContract::Base) do
          attribute :user_name, :string
          attribute :shipping_addresses, array: 'CamelAddressContract'
        end)
      end

      it '#as_camelcase_json camelizes keys inside each element' do
        attrs = { user_name: 'Al', shipping_addresses: [{ postal_code: '10001', street_name: 'Main' }] }
        element = CamelUserContract.new(attrs).as_camelcase_json['shippingAddresses'].first
        expect(element).to eq('postalCode' => '10001', 'streetName' => 'Main')
      end
    end
  end

  describe 'from_params / from_json' do
    it 'from_params instantiates nested contracts from arrays of hashes' do
      attrs = { name: 'Alice', addresses: [{ city: 'NYC', state: 'NY' }] }
      contract = user_class.from_params(attrs)
      expect(contract.addresses.first).to be_a(address_class)
    end

    it 'from_json instantiates nested contracts from parsed JSON arrays' do
      json = '{"name":"Alice","addresses":[{"city":"NYC","state":"NY"}]}'
      contract = user_class.from_json(json)
      expect(contract.addresses.first).to be_a(address_class)
    end

    it 'from_params raises on an invalid element schema' do
      attrs = { name: 'Alice', addresses: [{ city: 'NYC' }] }
      expect { user_class.from_params(attrs) }
        .to raise_error(ApiContract::MissingAttributeError, /state/)
    end

    it 'from_json raises on invalid element data' do
      json = '{"name":"Alice","addresses":[{"city":"NYC","state":"XYZ"}]}'
      expect { user_class.from_json(json) }
        .to raise_error(ApiContract::InvalidContractError)
    end
  end

  describe 'one_of inside array' do
    before do
      stub_const('USAddressContract', us_class)
      stub_const('UKAddressContract', uk_class)
    end

    let(:us_class) do
      Class.new(ApiContract::Base) do
        attribute :street, :string
        attribute :state, :string
        attribute :zip, :string
      end
    end

    let(:uk_class) do
      Class.new(ApiContract::Base) do
        attribute :street, :string
        attribute :county, :string
        attribute :postcode, :string
      end
    end

    let(:poly_class) do
      Class.new(ApiContract::Base) do
        attribute :name, :string
        attribute :addresses, array: ApiContract::Base.one_of('USAddressContract', 'UKAddressContract')
      end
    end

    it 'resolves each element to the first matching contract' do
      attrs = {
        name: 'HQ',
        addresses: [{ street: '1', state: 'NY', zip: '1' }, { street: '2', county: 'X', postcode: 'Y' }]
      }
      expect(poly_class.new(attrs).addresses.map(&:class)).to eq([us_class, uk_class])
    end

    it 'raises when an element matches no candidate and not permissive' do
      attrs = { name: 'HQ', addresses: [{ foo: 'bar' }] }
      expect { poly_class.new(attrs) }
        .to raise_error(ApiContract::UnexpectedAttributeError, /one_of/)
    end

    context 'with permissive: true' do
      before do
        stub_const('PermissivePolyContract', Class.new(ApiContract::Base) do
          attribute :name, :string
          attribute :addresses,
                    array: ApiContract::Base.one_of('USAddressContract', 'UKAddressContract'),
                    permissive: true
        end)
      end

      it 'falls back to a plain hash for non-matching elements' do
        contract = PermissivePolyContract.new(name: 'HQ', addresses: [{ foo: 'bar' }])
        expect(contract.addresses).to eq([{ foo: 'bar' }])
      end
    end
  end

  describe 'OpenAPI schema' do
    it 'emits a JSON Schema array with a $ref for the element contract' do
      schema = user_class.open_api_schema['properties']['addresses']
      expect(schema).to eq('type' => 'array', 'items' => { '$ref' => '#/components/schemas/AddressContract' })
    end

    it 'emits a oneOf items schema when the element is one_of' do
      klass = Class.new(ApiContract::Base) do
        attribute :items, array: ApiContract::Base.one_of('AddressContract')
      end
      items = klass.open_api_schema['properties']['items']['items']
      expect(items).to eq('oneOf' => [{ '$ref' => '#/components/schemas/AddressContract' }])
    end
  end

  describe 'to_params' do
    it 'exposes nested contract arrays as arrays of hashes' do
      contract = user_class.new(name: 'Alice', addresses: [{ city: 'NYC', state: 'NY' }])
      params = contract.to_params
      expect(params[:addresses].first[:city]).to eq('NYC')
    end
  end

  describe 'immutability' do
    it 'freezes each nested element as read-only' do
      contract = user_class.new(name: 'Alice', addresses: [{ city: 'NYC', state: 'NY' }])
      expect(contract.addresses.first).to be_read_only
    end
  end
end
