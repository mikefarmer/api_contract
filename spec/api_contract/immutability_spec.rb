# frozen_string_literal: true

RSpec.describe ApiContract::Immutability do
  let(:contract_class) do
    klass = Class.new(ApiContract::Base) do
      attribute :name, :string
      attribute :age, :integer, optional: true
      attribute :code, :string, default: '000'

      validates :name, length: { minimum: 2 }
    end
    stub_const('ImmutableTestContract', klass)
  end

  describe '#read_only?' do
    it 'returns true for contracts created via .new' do
      contract = contract_class.new(name: 'Alice')
      expect(contract.read_only?).to be true
    end

    it 'returns true for contracts created via .from_params' do
      contract = contract_class.from_params(name: 'Alice')
      expect(contract.read_only?).to be true
    end

    it 'returns true for contracts created via .from_json' do
      contract = contract_class.from_json('{"name": "Alice"}')
      expect(contract.read_only?).to be true
    end

    it 'returns false for dup-ed contracts' do
      contract = contract_class.new(name: 'Alice').dup
      expect(contract.read_only?).to be false
    end
  end

  describe 'frozen attribute writers' do
    it 'raises FrozenError when setting attributes on a read-only contract' do
      contract = contract_class.new(name: 'Alice')
      expect { contract.name = 'Bob' }.to raise_error(FrozenError)
    end

    it 'raises FrozenError for optional attributes' do
      contract = contract_class.new(name: 'Alice')
      expect { contract.age = 30 }.to raise_error(FrozenError)
    end

    it 'allows setting attributes on a dup-ed contract' do
      contract = contract_class.new(name: 'Alice').dup
      contract.name = 'Bob'
      expect(contract.name).to eq('Bob')
    end
  end

  describe '#clone' do
    it 'returns a new immutable contract with changed attributes' do
      contract = contract_class.new(name: 'Alice', age: 25)
      cloned = contract.clone(age: 30)
      expect(cloned.age).to eq(30)
    end

    it 'preserves unchanged attributes' do
      contract = contract_class.new(name: 'Alice', age: 25)
      cloned = contract.clone(age: 30)
      expect(cloned.name).to eq('Alice')
    end

    it 'returns an immutable contract' do
      contract = contract_class.new(name: 'Alice')
      cloned = contract.clone(age: 30)
      expect(cloned.read_only?).to be true
    end

    it 'accepts no changes and returns a copy' do
      contract = contract_class.new(name: 'Alice')
      cloned = contract.clone
      expect(cloned.name).to eq('Alice')
    end

    it 'calls schema_validate! internally' do
      contract = contract_class.new(name: 'Alice')
      expect { contract.clone(foo: 'bar') }.to raise_error(ApiContract::UnexpectedAttributeError)
    end

    it 'does not modify the original contract' do
      contract = contract_class.new(name: 'Alice', age: 25)
      contract.clone(age: 30)
      expect(contract.age).to eq(25)
    end
  end

  describe '#dup' do
    it 'returns a mutable copy' do
      contract = contract_class.new(name: 'Alice')
      duped = contract.dup
      expect(duped.read_only?).to be false
    end

    it 'preserves attribute values' do
      contract = contract_class.new(name: 'Alice', age: 25)
      duped = contract.dup
      expect(duped.name).to eq('Alice')
    end

    it 'allows attribute writes' do
      duped = contract_class.new(name: 'Alice').dup
      duped.age = 30
      expect(duped.age).to eq(30)
    end

    it 'does not affect the original contract' do
      contract = contract_class.new(name: 'Alice', age: 25)
      duped = contract.dup
      duped.name = 'Bob'
      expect(contract.name).to eq('Alice')
    end
  end

  describe '#mutate' do
    it 'returns a new immutable contract with changed attributes' do
      contract = contract_class.new(name: 'Alice', age: 25)
      mutated = contract.mutate(age: 30)
      expect(mutated.age).to eq(30)
    end

    it 'returns an immutable contract' do
      contract = contract_class.new(name: 'Alice')
      mutated = contract.mutate(age: 30)
      expect(mutated.read_only?).to be true
    end

    it 'raises ArgumentError when no changes are provided' do
      contract = contract_class.new(name: 'Alice')
      expect { contract.mutate }.to raise_error(ArgumentError, /at least one/)
    end

    it 'calls schema_validate! internally' do
      contract = contract_class.new(name: 'Alice')
      expect { contract.mutate(foo: 'bar') }.to raise_error(ApiContract::UnexpectedAttributeError)
    end

    it 'preserves unchanged attributes' do
      contract = contract_class.new(name: 'Alice', age: 25)
      mutated = contract.mutate(name: 'Bob')
      expect(mutated.age).to eq(25)
    end
  end

  describe '#merge' do
    it 'deep merges another contract into the receiver' do
      contract1 = contract_class.new(name: 'Alice', age: 25)
      contract2 = contract_class.new(name: 'Bob')
      merged = contract1.merge(contract2)
      expect(merged.name).to eq('Bob')
    end

    it 'preserves attributes not present in the argument' do
      contract1 = contract_class.new(name: 'Alice', age: 25)
      contract2 = contract_class.new(name: 'Bob')
      merged = contract1.merge(contract2)
      expect(merged.age).to eq(25)
    end

    it 'returns an immutable contract' do
      contract1 = contract_class.new(name: 'Alice')
      contract2 = contract_class.new(name: 'Bob')
      merged = contract1.merge(contract2)
      expect(merged.read_only?).to be true
    end

    it 'accepts a plain hash as the argument' do
      contract = contract_class.new(name: 'Alice', age: 25)
      merged = contract.merge({ name: 'Bob' }, strict: false)
      expect(merged.name).to eq('Bob')
    end

    it 'runs schema_validate! by default' do
      contract = contract_class.new(name: 'Alice')
      expect { contract.merge({ foo: 'bar' }) }.to raise_error(ApiContract::UnexpectedAttributeError)
    end

    it 'skips schema_validate! when strict: false' do
      contract = contract_class.new(name: 'Alice')
      expect { contract.merge({ name: 'Bob' }, strict: false) }.not_to raise_error
    end

    it 'runs valid? by default and raises on failure' do
      contract = contract_class.new(name: 'Alice')
      expect { contract.merge(contract_class.new(name: 'A')) }.to raise_error(ApiContract::InvalidContractError)
    end

    it 'skips valid? when validate: false' do
      contract = contract_class.new(name: 'Alice')
      merged = contract.merge(contract_class.new(name: 'A'), validate: false)
      expect(merged.name).to eq('A')
    end

    context 'with permissive_hash attributes' do
      let(:hash_class) do
        klass = Class.new(ApiContract::Base) do
          attribute :name, :string
          attribute :data, :permissive_hash, optional: true
        end
        stub_const('MergeHashContract', klass)
      end

      it 'deep merges nested hashes' do
        c1 = hash_class.new(name: 'A', data: { a: 1, b: 2 })
        c2 = hash_class.new(name: 'A', data: { b: 3, c: 4 })
        merged = c1.merge(c2)
        expect(merged.data).to eq(a: 1, b: 3, c: 4)
      end
    end
  end
end
