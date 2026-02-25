# frozen_string_literal: true

RSpec.describe ApiContract::NestedContract do
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
      attribute :home_address, contract: 'AddressContract'
    end
  end

  describe 'contract: option with class reference' do
    let(:class_ref_user) do
      addr = address_class
      Class.new(ApiContract::Base) do
        attribute :name, :string
        attribute :home_address, contract: addr
      end
    end

    it 'instantiates nested contract from hash' do
      contract = class_ref_user.new(name: 'Alice', home_address: { city: 'NYC', state: 'NY' })
      expect(contract.home_address).to be_a(address_class)
    end

    it 'sets nested contract values' do
      contract = class_ref_user.new(name: 'Alice', home_address: { city: 'NYC', state: 'NY' })
      expect(contract.home_address.city).to eq('NYC')
    end
  end

  describe 'contract: option with string reference' do
    it 'resolves string references at runtime' do
      contract = user_class.new(name: 'Alice', home_address: { city: 'NYC', state: 'NY' })
      expect(contract.home_address).to be_a(address_class)
    end

    it 'memoizes resolved classes' do
      user_class.new(name: 'A', home_address: { city: 'X', state: 'NY' })
      user_class.new(name: 'B', home_address: { city: 'Y', state: 'CA' })
      expect(user_class.resolve_contract('AddressContract')).to eq(address_class)
    end
  end

  describe 'nested instantiation' do
    let(:optional_nested_class) do
      klass = Class.new(ApiContract::Base) do
        attribute :name, :string
        attribute :address, contract: 'AddressContract', optional: true
      end
      stub_const('OptionalNestedContract', klass)
    end

    it 'converts hash values to contract instances' do
      contract = user_class.new(name: 'Alice', home_address: { city: 'NYC', state: 'NY' })
      expect(contract.home_address).to be_a(address_class)
    end

    it 'leaves nil values as nil for optional contracts' do
      contract = optional_nested_class.new(name: 'Alice')
      expect(contract.address).to be_nil
    end
  end

  describe 'recursive schema validation' do
    it 'raises MissingAttributeError for missing nested attributes' do
      contract = user_class.new(name: 'Alice', home_address: { city: 'NYC' })
      expect { contract.schema_validate! }.to raise_error(ApiContract::MissingAttributeError, /state/)
    end

    it 'raises UnexpectedAttributeError for unexpected nested attributes' do
      attrs = { city: 'NYC', state: 'NY', zip: '10001' }
      contract = user_class.new(name: 'Alice', home_address: attrs)
      expect { contract.schema_validate! }.to raise_error(ApiContract::UnexpectedAttributeError, /zip/)
    end

    it 'passes when nested contract is valid' do
      contract = user_class.new(name: 'Alice', home_address: { city: 'NYC', state: 'NY' })
      expect { contract.schema_validate! }.not_to raise_error
    end
  end

  describe 'nested error propagation' do
    it 'propagates nested errors with dot-notation keys' do
      contract = user_class.new(name: 'Alice', home_address: { city: 'NYC', state: 'XYZ' })
      contract.valid?
      expect(contract.errors[:'home_address.state']).to include(/is the wrong length/)
    end

    it 'parent is invalid when nested contract is invalid' do
      contract = user_class.new(name: 'Alice', home_address: { city: 'NYC', state: 'XYZ' })
      expect(contract.valid?).to be false
    end

    it 'parent is valid when nested contract is valid' do
      contract = user_class.new(name: 'Alice', home_address: { city: 'NYC', state: 'NY' })
      expect(contract.valid?).to be true
    end
  end

  describe 'nested serialization' do
    let(:contract) do
      user_class.new(name: 'Alice', home_address: { city: 'NYC', state: 'NY' })
    end

    it '#to_h returns nested contract as a hash' do
      result = contract.to_h
      expect(result[:home_address]).to eq(city: 'NYC', state: 'NY')
    end

    it '#as_json returns nested contract with string keys' do
      result = contract.as_json
      expect(result['home_address']).to eq('city' => 'NYC', 'state' => 'NY')
    end

    it '#to_json includes nested contract' do
      parsed = JSON.parse(contract.to_json)
      expect(parsed['home_address']['city']).to eq('NYC')
    end

    context 'with camelCase nested contracts' do
      let(:camel_address_class) do
        klass = Class.new(ApiContract::Base) do
          attribute :postal_code, :string
          attribute :street_name, :string
        end
        stub_const('CamelAddressContract', klass)
      end

      let(:camel_user_class) do
        camel_address_class
        klass = Class.new(ApiContract::Base) do
          attribute :user_name, :string
          attribute :home_address, contract: 'CamelAddressContract'
        end
        stub_const('CamelUserContract', klass)
      end

      it '#as_camelcase_json converts nested keys to camelCase' do
        c = camel_user_class.new(user_name: 'Al', home_address: { postal_code: '10001', street_name: 'Main' })
        expect(c.as_camelcase_json.dig('homeAddress', 'postalCode')).to eq('10001')
      end
    end
  end

  describe 'from_params / from_json nesting' do
    it 'from_params instantiates nested contracts from hashes' do
      contract = user_class.from_params(name: 'Alice', home_address: { city: 'NYC', state: 'NY' })
      expect(contract.home_address).to be_a(address_class)
    end

    it 'from_json instantiates nested contracts from parsed JSON' do
      json = '{"name": "Alice", "home_address": {"city": "NYC", "state": "NY"}}'
      contract = user_class.from_json(json)
      expect(contract.home_address).to be_a(address_class)
    end

    it 'from_params raises on invalid nested schema' do
      expect { user_class.from_params(name: 'Alice', home_address: { city: 'NYC' }) }
        .to raise_error(ApiContract::MissingAttributeError, /state/)
    end

    it 'from_json raises on invalid nested data' do
      json = '{"name": "Alice", "home_address": {"city": "NYC", "state": "XYZ"}}'
      expect { user_class.from_json(json) }
        .to raise_error(ApiContract::InvalidContractError)
    end
  end
end
