# frozen_string_literal: true

RSpec.describe ApiContract::Base do
  let(:contract_class) do
    Class.new(described_class) do
      attribute :name, :string, description: 'Full name'
      attribute :age,  :integer, optional: true, description: 'Age in years'
      attribute :code, :string, default: '000', description: 'Code'
    end
  end

  describe '.attribute' do
    it 'registers type metadata' do
      expect(contract_class.attribute_registry[:name][:type]).to eq(:string)
    end

    it 'registers optional as false by default' do
      expect(contract_class.attribute_registry[:name][:optional]).to be false
    end

    it 'registers description metadata' do
      expect(contract_class.attribute_registry[:name][:description]).to eq('Full name')
    end

    it 'records optional flag when set' do
      expect(contract_class.attribute_registry[:age][:optional]).to be true
    end

    it 'records has_default flag' do
      expect(contract_class.attribute_registry[:code][:has_default]).to be true
    end

    it 'records default value' do
      expect(contract_class.attribute_registry[:code][:default]).to eq('000')
    end

    it 'delegates to ActiveModel so reader methods exist' do
      expect(contract_class.new(name: 'Alice')).to respond_to(:name)
    end
  end

  describe '.required_attribute_names' do
    it 'excludes optional attributes' do
      expect(contract_class.required_attribute_names).not_to include(:age)
    end

    it 'excludes attributes with defaults' do
      expect(contract_class.required_attribute_names).not_to include(:code)
    end

    it 'includes required attributes without defaults' do
      expect(contract_class.required_attribute_names).to eq([:name])
    end
  end

  describe '.declared_attribute_names' do
    it 'returns all declared attribute names' do
      expect(contract_class.declared_attribute_names).to contain_exactly(:name, :age, :code)
    end
  end

  describe '.new' do
    it 'never raises with valid attributes' do
      expect { contract_class.new(name: 'Alice') }.not_to raise_error
    end

    it 'never raises with missing required attributes' do
      expect { contract_class.new({}) }.not_to raise_error
    end

    it 'never raises with unexpected attributes' do
      expect { contract_class.new(name: 'Alice', foo: 'bar') }.not_to raise_error
    end

    it 'never raises with nil' do
      expect { contract_class.new(nil) }.not_to raise_error
    end

    it 'sets attribute values' do
      contract = contract_class.new(name: 'Alice', age: 30)
      expect(contract.name).to eq('Alice')
    end

    it 'applies default when attribute is absent' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.code).to eq('000')
    end
  end

  describe 'type coercion' do
    it 'coerces string type' do
      klass = Class.new(described_class) { attribute :val, :string }
      expect(klass.new(val: 123).val).to eq('123')
    end

    it 'coerces integer type' do
      klass = Class.new(described_class) { attribute :val, :integer }
      expect(klass.new(val: '42').val).to eq(42)
    end

    it 'coerces float type' do
      klass = Class.new(described_class) { attribute :val, :float }
      expect(klass.new(val: '3.14').val).to be_within(0.001).of(3.14)
    end

    it 'coerces decimal type' do
      klass = Class.new(described_class) { attribute :val, :decimal }
      expect(klass.new(val: '99.99').val).to eq(BigDecimal('99.99'))
    end

    it 'coerces boolean true' do
      klass = Class.new(described_class) { attribute :val, :boolean }
      expect(klass.new(val: '1').val).to be true
    end

    it 'coerces boolean false' do
      klass = Class.new(described_class) { attribute :val, :boolean }
      expect(klass.new(val: '0').val).to be false
    end

    it 'coerces date type' do
      klass = Class.new(described_class) { attribute :val, :date }
      expect(klass.new(val: '2024-01-15').val).to eq(Date.new(2024, 1, 15))
    end

    it 'coerces datetime type' do
      klass = Class.new(described_class) { attribute :val, :datetime }
      expect(klass.new(val: '2024-01-15T10:30:00Z').val).to be_a(Time)
    end

    it 'coerces time type' do
      klass = Class.new(described_class) { attribute :val, :time }
      expect(klass.new(val: '2024-01-15T10:30:00Z').val).to be_a(Time)
    end

    it 'coerces big_integer type' do
      klass = Class.new(described_class) { attribute :val, :big_integer }
      expect(klass.new(val: '999999999999').val).to eq(999_999_999_999)
    end
  end

  describe '#provided_keys' do
    it 'tracks explicitly provided keys' do
      contract = contract_class.new(name: 'Alice', age: 25)
      expect(contract.provided_keys).to contain_exactly(:name, :age)
    end

    it 'excludes keys not provided' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.provided_keys).not_to include(:code)
    end

    it 'is frozen' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.provided_keys).to be_frozen
    end
  end

  describe '#provided?' do
    it 'returns true for provided keys' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.provided?(:name)).to be true
    end

    it 'returns false for unprovided keys' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.provided?(:age)).to be false
    end

    it 'accepts string keys' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.provided?('name')).to be true
    end
  end

  describe '#unexpected_attributes' do
    it 'returns unexpected key-value pairs' do
      contract = contract_class.new(name: 'Alice', foo: 'bar', baz: 42)
      expect(contract.unexpected_attributes).to eq(foo: 'bar', baz: 42)
    end

    it 'returns empty hash when all keys are declared' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.unexpected_attributes).to eq({})
    end

    it 'is frozen' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.unexpected_attributes).to be_frozen
    end
  end

  describe '#schema_valid?' do
    it 'returns true with all required attributes' do
      expect(contract_class.new(name: 'Alice').schema_valid?).to be true
    end

    it 'returns false when required attributes are missing' do
      expect(contract_class.new({}).schema_valid?).to be false
    end

    it 'returns false when unexpected attributes are present' do
      expect(contract_class.new(name: 'Alice', foo: 'bar').schema_valid?).to be false
    end

    it 'returns true when only optional attributes are absent' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.schema_errors).not_to have_key(:age)
    end

    it 'returns true when only defaulted attributes are absent' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.schema_errors).not_to have_key(:code)
    end
  end

  describe '#schema_errors' do
    it 'returns empty hash when valid' do
      expect(contract_class.new(name: 'Alice').schema_errors).to be_empty
    end

    it 'reports missing required attributes' do
      expect(contract_class.new({}).schema_errors[:name]).to eq(['is missing'])
    end

    it 'reports unexpected attributes' do
      errors = contract_class.new(name: 'Alice', foo: 'bar').schema_errors
      expect(errors[:foo]).to eq(['is unexpected'])
    end

    it 'reports both missing and unexpected errors' do
      errors = contract_class.new(foo: 'bar').schema_errors
      expect(errors.keys).to contain_exactly(:name, :foo)
    end
  end

  describe '#schema_validate!' do
    it 'returns nil when valid' do
      expect(contract_class.new(name: 'Alice').schema_validate!).to be_nil
    end

    it 'raises MissingAttributeError for missing required attributes' do
      expect { contract_class.new({}).schema_validate! }
        .to raise_error(ApiContract::MissingAttributeError, /name/)
    end

    it 'includes attribute names on MissingAttributeError' do
      contract_class.new({}).schema_validate!
    rescue ApiContract::MissingAttributeError => e
      expect(e.attributes).to eq([:name])
    end

    it 'raises UnexpectedAttributeError for unexpected attributes' do
      expect { contract_class.new(name: 'Alice', foo: 'bar').schema_validate! }
        .to raise_error(ApiContract::UnexpectedAttributeError, /foo/)
    end

    it 'includes attribute names on UnexpectedAttributeError' do
      contract_class.new(name: 'Alice', foo: 'bar').schema_validate!
    rescue ApiContract::UnexpectedAttributeError => e
      expect(e.attributes).to eq([:foo])
    end

    it 'checks missing before unexpected' do
      expect { contract_class.new(foo: 'bar').schema_validate! }
        .to raise_error(ApiContract::MissingAttributeError)
    end
  end

  describe 'inheritance' do
    let(:parent_class) do
      Class.new(described_class) do
        attribute :name, :string
        attribute :code, :string, default: 'parent'
      end
    end

    let(:child_class) do
      Class.new(parent_class) do
        attribute :email, :string
        attribute :code,  :string, default: 'child'
      end
    end

    it 'inherits parent attributes' do
      expect(child_class.declared_attribute_names).to include(:name)
    end

    it 'adds its own attributes' do
      expect(child_class.declared_attribute_names).to include(:email)
    end

    it 'can override defaults' do
      contract = child_class.new(name: 'Alice', email: 'a@b.com')
      expect(contract.code).to eq('child')
    end

    it 'does not add child attributes to parent' do
      child_class # force evaluation
      expect(parent_class.declared_attribute_names).not_to include(:email)
    end

    it 'does not mutate parent default' do
      child_class # force evaluation
      expect(parent_class.attribute_registry[:code][:default]).to eq('parent')
    end
  end

  describe 'string keys' do
    it 'symbolizes string keys on input' do
      contract = contract_class.new('name' => 'Alice', 'age' => 30)
      expect(contract.name).to eq('Alice')
    end

    it 'tracks symbolized keys as provided' do
      contract = contract_class.new('name' => 'Alice')
      expect(contract.provided?(:name)).to be true
    end
  end

  describe 'default + nil' do
    it 'applies default when attribute is explicitly nil' do
      contract = contract_class.new(name: 'Alice', code: nil)
      expect(contract.code).to eq('000')
    end

    it 'does not track nil-defaulted keys as provided' do
      contract = contract_class.new(name: 'Alice', code: nil)
      expect(contract.provided?(:code)).to be false
    end

    it 'tracks non-nil values as provided even when default exists' do
      contract = contract_class.new(name: 'Alice', code: 'XYZ')
      expect(contract.provided?(:code)).to be true
    end

    it 'uses the provided value when not nil' do
      contract = contract_class.new(name: 'Alice', code: 'XYZ')
      expect(contract.code).to eq('XYZ')
    end
  end

  describe '.from_params' do
    let(:validated_class) do
      klass = Class.new(described_class) do
        attribute :name, :string
        attribute :age,  :integer, optional: true
        attribute :code, :string, default: '000'

        validates :name, length: { minimum: 2 }
      end
      stub_const('ValidatedParamsContract', klass)
    end

    it 'accepts a plain hash and returns a valid contract' do
      contract = validated_class.from_params(name: 'Alice')
      expect(contract.name).to eq('Alice')
    end

    it 'applies defaults when constructing from params' do
      contract = validated_class.from_params(name: 'Alice')
      expect(contract.code).to eq('000')
    end

    it 'accepts an object responding to to_unsafe_h' do
      params = Struct.new(:to_unsafe_h).new({ 'name' => 'Bob', 'age' => 25 })
      contract = validated_class.from_params(params)
      expect(contract.name).to eq('Bob')
    end

    it 'raises MissingAttributeError when required attrs are missing' do
      expect { validated_class.from_params({}) }
        .to raise_error(ApiContract::MissingAttributeError, /name/)
    end

    it 'raises UnexpectedAttributeError when extra attrs are present' do
      expect { validated_class.from_params(name: 'Alice', foo: 'bar') }
        .to raise_error(ApiContract::UnexpectedAttributeError, /foo/)
    end

    it 'raises InvalidContractError when data validations fail' do
      expect { validated_class.from_params(name: 'A') }
        .to raise_error(ApiContract::InvalidContractError)
    end

    it 'exposes the contract on InvalidContractError' do
      validated_class.from_params(name: 'A')
    rescue ApiContract::InvalidContractError => e
      expect(e.contract).to be_a(described_class)
    end

    it 'handles optional attributes correctly' do
      contract = validated_class.from_params(name: 'Alice')
      expect(contract.age).to be_nil
    end

    it 'handles default values correctly' do
      contract = validated_class.from_params(name: 'Alice', code: 'XYZ')
      expect(contract.code).to eq('XYZ')
    end
  end

  describe '.from_json' do
    let(:validated_class) do
      klass = Class.new(described_class) do
        attribute :name, :string
        attribute :age,  :integer, optional: true
        attribute :code, :string, default: '000'

        validates :name, length: { minimum: 2 }
      end
      stub_const('ValidatedJsonContract', klass)
    end

    it 'parses a JSON string and returns a valid contract' do
      contract = validated_class.from_json('{"name": "Alice", "age": 30}')
      expect(contract.name).to eq('Alice')
    end

    it 'coerces JSON values to declared types' do
      contract = validated_class.from_json('{"name": "Alice", "age": 30}')
      expect(contract.age).to eq(30)
    end

    it 'raises JSON::ParserError for malformed JSON' do
      expect { validated_class.from_json('not json') }
        .to raise_error(JSON::ParserError)
    end

    it 'raises MissingAttributeError when required attrs are missing' do
      expect { validated_class.from_json('{}') }
        .to raise_error(ApiContract::MissingAttributeError, /name/)
    end

    it 'raises UnexpectedAttributeError when extra attrs are present' do
      expect { validated_class.from_json('{"name": "Alice", "foo": "bar"}') }
        .to raise_error(ApiContract::UnexpectedAttributeError, /foo/)
    end

    it 'raises InvalidContractError when data validations fail' do
      expect { validated_class.from_json('{"name": "A"}') }
        .to raise_error(ApiContract::InvalidContractError)
    end

    it 'coerces types from JSON strings' do
      klass = Class.new(described_class) do
        attribute :count, :integer
      end
      contract = klass.from_json('{"count": 42}')
      expect(contract.count).to eq(42)
    end

    it 'applies default values' do
      contract = validated_class.from_json('{"name": "Alice"}')
      expect(contract.code).to eq('000')
    end
  end

  describe 'permissive_hash attribute' do
    let(:hash_contract_class) do
      Class.new(described_class) do
        attribute :name, :string
        attribute :metadata, :permissive_hash, optional: true
      end
    end

    it 'accepts a hash and symbolizes keys' do
      contract = hash_contract_class.new(name: 'Alice', metadata: { 'role' => 'admin' })
      expect(contract.metadata).to eq(role: 'admin')
    end

    it 'deep-symbolizes nested keys' do
      contract = hash_contract_class.new(name: 'Alice', metadata: { 'a' => { 'b' => 1 } })
      expect(contract.metadata).to eq(a: { b: 1 })
    end

    it 'registers permissive_hash type in the attribute registry' do
      expect(hash_contract_class.attribute_registry[:metadata][:type]).to eq(:permissive_hash)
    end

    it 'is schema valid when optional and absent' do
      contract = hash_contract_class.new(name: 'Alice')
      expect(contract.schema_valid?).to be true
    end

    it 'is schema valid when provided with a hash' do
      contract = hash_contract_class.new(name: 'Alice', metadata: { x: 1 })
      expect(contract.schema_valid?).to be true
    end

    it 'returns nil when not provided' do
      contract = hash_contract_class.new(name: 'Alice')
      expect(contract.metadata).to be_nil
    end
  end

  describe '#attributes' do
    let(:ordered_class) do
      Class.new(described_class) do
        attribute :z_field, :string
        attribute :a_field, :string
        attribute :m_field, :string
      end
    end

    it 'returns an array of declared attribute names as symbols' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.attributes).to eq(%i[name age code])
    end

    it 'preserves declaration order' do
      contract = ordered_class.new(z_field: 'z', a_field: 'a', m_field: 'm')
      expect(contract.attributes).to eq(%i[z_field a_field m_field])
    end
  end

  describe '#values' do
    it 'returns attribute values in declaration order' do
      contract = contract_class.new(name: 'Alice', age: 30)
      expect(contract.values).to eq(['Alice', 30, '000'])
    end

    it 'includes nil for unprovided optional attributes' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.values).to eq(['Alice', nil, '000'])
    end
  end

  describe '#to_h' do
    it 'returns a symbolized hash of declared attributes' do
      contract = contract_class.new(name: 'Alice', age: 30)
      expect(contract.to_h).to eq(name: 'Alice', age: 30, code: '000')
    end

    it 'excludes optional attributes with nil values' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.to_h).not_to have_key(:age)
    end

    it 'includes optional attributes with non-nil values' do
      contract = contract_class.new(name: 'Alice', age: 25)
      expect(contract.to_h).to have_key(:age)
    end

    it 'does not include unexpected attributes' do
      contract = contract_class.new(name: 'Alice', foo: 'bar')
      expect(contract.to_h).not_to have_key(:foo)
    end

    it 'includes default values' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.to_h[:code]).to eq('000')
    end
  end

  describe '#as_json' do
    let(:validated_class) do
      klass = Class.new(described_class) do
        attribute :name, :string
        attribute :age, :integer, optional: true

        validates :name, length: { minimum: 2 }
      end
      stub_const('AsJsonContract', klass)
    end

    it 'returns a string-keyed hash' do
      contract = validated_class.new(name: 'Alice', age: 30)
      expect(contract.as_json).to eq('name' => 'Alice', 'age' => 30)
    end

    it 'excludes optional nil attributes' do
      contract = validated_class.new(name: 'Alice')
      expect(contract.as_json).not_to have_key('age')
    end

    it 'raises InvalidContractError when data validations fail' do
      contract = validated_class.new(name: 'A')
      expect { contract.as_json }.to raise_error(ApiContract::InvalidContractError)
    end

    it 'raises InvalidContractError when schema is invalid' do
      contract = validated_class.new({})
      expect { contract.as_json }.to raise_error(ApiContract::InvalidContractError)
    end

    it 'exposes the contract on the error' do
      contract = validated_class.new(name: 'A')
      contract.as_json
    rescue ApiContract::InvalidContractError => e
      expect(e.contract).to eq(contract)
    end
  end

  describe '#to_json' do
    let(:validated_class) do
      klass = Class.new(described_class) do
        attribute :name, :string
        attribute :count, :integer

        validates :name, length: { minimum: 2 }
      end
      stub_const('ToJsonContract', klass)
    end

    it 'returns a JSON string' do
      contract = validated_class.new(name: 'Alice', count: 5)
      parsed = JSON.parse(contract.to_json)
      expect(parsed).to eq('name' => 'Alice', 'count' => 5)
    end

    it 'raises InvalidContractError when invalid' do
      contract = validated_class.new(name: 'A', count: 5)
      expect { contract.to_json }.to raise_error(ApiContract::InvalidContractError)
    end

    it 'raises InvalidContractError when schema is invalid' do
      contract = validated_class.new({})
      expect { contract.to_json }.to raise_error(ApiContract::InvalidContractError)
    end
  end

  describe '#as_camelcase_json' do
    let(:camel_class) do
      klass = Class.new(described_class) do
        attribute :first_name, :string
        attribute :last_name, :string
        attribute :home_address_line, :string, optional: true
      end
      stub_const('CamelCaseContract', klass)
    end

    it 'returns string-keyed hash with camelCase keys' do
      contract = camel_class.new(first_name: 'Alice', last_name: 'Smith')
      result = contract.as_camelcase_json
      expect(result).to eq('firstName' => 'Alice', 'lastName' => 'Smith')
    end

    it 'converts multi-underscore keys to camelCase' do
      contract = camel_class.new(first_name: 'Alice', last_name: 'Smith', home_address_line: '123 Main')
      expect(contract.as_camelcase_json).to have_key('homeAddressLine')
    end

    it 'excludes optional nil attributes' do
      contract = camel_class.new(first_name: 'Alice', last_name: 'Smith')
      expect(contract.as_camelcase_json).not_to have_key('homeAddressLine')
    end

    it 'raises InvalidContractError when schema is invalid' do
      contract = camel_class.new({})
      expect { contract.as_camelcase_json }.to raise_error(ApiContract::InvalidContractError)
    end

    it 'raises InvalidContractError when data validations fail' do
      contract = camel_class.new(first_name: 'A', last_name: 'S')
      camel_class.validates :first_name, length: { minimum: 5 }
      expect { contract.as_camelcase_json }.to raise_error(ApiContract::InvalidContractError)
    end
  end

  describe '#dig' do
    it 'retrieves nested values through permissive_hash' do
      klass = Class.new(described_class) do
        attribute :data, :permissive_hash
      end
      contract = klass.new(data: { nested: { deep: 'value' } })
      expect(contract.dig(:data, :nested, :deep)).to eq('value')
    end

    it 'returns nil when nested key path does not exist' do
      klass = Class.new(described_class) do
        attribute :data, :permissive_hash
      end
      contract = klass.new(data: { a: 1 })
      expect(contract.dig(:data, :missing, :key)).to be_nil
    end
  end
end
