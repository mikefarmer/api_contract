# frozen_string_literal: true

RSpec.describe ApiContract::PermissiveAttributes do
  let(:contract_class) do
    klass = Class.new(ApiContract::Base) do
      include ApiContract::PermissiveAttributes

      attribute :name, :string
      attribute :data, :permissive_hash, optional: true
    end
    stub_const('PermissiveTestContract', klass)
  end

  let(:contract) do
    contract_class.new(name: 'test', data: {}, foo: 'bar', baz: 42)
  end

  describe '#permissive?' do
    it 'returns true when the module is included' do
      expect(contract.permissive?).to be true
    end

    it 'returns false on standard contracts' do
      klass = Class.new(ApiContract::Base) { attribute :name, :string }
      expect(klass.new(name: 'x').permissive?).to be false
    end
  end

  describe '#key?' do
    it 'returns true for declared attributes' do
      expect(contract.key?(:name)).to be true
    end

    it 'returns true for permissive attributes' do
      expect(contract.key?(:foo)).to be true
    end

    it 'returns false for absent keys' do
      expect(contract.key?(:missing)).to be false
    end
  end

  describe '#declared_attribute?' do
    it 'returns true for declared attributes' do
      expect(contract.declared_attribute?(:name)).to be true
    end

    it 'returns false for permissive attributes' do
      expect(contract.declared_attribute?(:foo)).to be false
    end
  end

  describe '#permissive_attributes' do
    it 'returns hash of unknown keys/values' do
      expect(contract.permissive_attributes).to eq(foo: 'bar', baz: 42)
    end
  end

  describe '#attributes' do
    it 'returns only declared attribute names' do
      expect(contract.attributes).to eq(%i[name data])
    end
  end

  describe '#as_json' do
    it 'excludes permissive attributes by default' do
      result = contract.as_json
      expect(result).not_to have_key('foo')
    end

    it 'includes permissive attributes when permissive: true' do
      result = contract.as_json(permissive: true)
      expect(result['foo']).to eq('bar')
    end

    it 'includes declared attributes either way' do
      result = contract.as_json(permissive: true)
      expect(result['name']).to eq('test')
    end
  end

  describe '#with_passthrough_attributes' do
    it 'returns a wrapper that includes permissive attributes in to_h' do
      result = contract.with_passthrough_attributes.to_h
      expect(result).to include(name: 'test', foo: 'bar', baz: 42)
    end
  end

  describe 'disabled strict deserialization' do
    it 'from_params does not raise UnexpectedAttributeError' do
      expect { contract_class.from_params(name: 'Alice', unknown: 'val') }
        .not_to raise_error
    end

    it 'from_json does not raise UnexpectedAttributeError' do
      json = '{"name":"Alice","unknown":"val"}'
      expect { contract_class.from_json(json) }.not_to raise_error
    end

    it 'stores unknown keys from from_params in permissive_attributes' do
      c = contract_class.from_params(name: 'Alice', extra: 'data')
      expect(c.permissive_attributes).to eq(extra: 'data')
    end

    it 'still raises MissingAttributeError for required attributes' do
      expect { contract_class.from_params(extra: 'data') }
        .to raise_error(ApiContract::MissingAttributeError)
    end
  end
end
