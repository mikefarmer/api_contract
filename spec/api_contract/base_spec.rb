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
end
