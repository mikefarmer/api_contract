# frozen_string_literal: true

RSpec.describe ApiContract::Types::PermissiveHash do
  subject(:type) { described_class.new }

  describe '#cast' do
    it 'returns nil for nil' do
      expect(type.cast(nil)).to be_nil
    end

    it 'returns empty hash unchanged' do
      expect(type.cast({})).to eq({})
    end

    it 'passes through hashes with symbol keys' do
      input = { a: 1, b: 'two' }
      expect(type.cast(input)).to eq(input)
    end

    it 'symbolizes string keys' do
      expect(type.cast('a' => 1, 'b' => 2)).to eq(a: 1, b: 2)
    end

    it 'symbolizes nested hash keys' do
      input = { 'a' => { 'b' => { 'c' => 3 } } }
      expect(type.cast(input)).to eq(a: { b: { c: 3 } })
    end

    it 'passes through a string' do
      expect(type.cast('hello')).to eq('hello')
    end

    it 'passes through an integer' do
      expect(type.cast(42)).to eq(42)
    end

    it 'passes through an array' do
      expect(type.cast([1, 2, 3])).to eq([1, 2, 3])
    end
  end

  describe '#type' do
    it 'returns :permissive_hash' do
      expect(type.type).to eq(:permissive_hash)
    end
  end

  describe 'strict coercion integration' do
    let(:contract_class) do
      Class.new(ApiContract::Base) do
        attribute :data, :permissive_hash
      end
    end

    it 'adds a validation error for a string value' do
      contract = contract_class.new(data: 'not a hash')
      contract.valid?
      expect(contract.errors[:data]).to include(match(/is not a valid permissive_hash/))
    end

    it 'adds a validation error for an integer value' do
      contract = contract_class.new(data: 42)
      contract.valid?
      expect(contract.errors[:data]).to include(match(/is not a valid permissive_hash/))
    end

    it 'is valid with a hash value' do
      contract = contract_class.new(data: { key: 'value' })
      contract.valid?
      expect(contract.errors[:data]).to be_empty
    end

    it 'adds a validation error for nil when required' do
      contract = contract_class.new(data: nil)
      contract.valid?
      expect(contract.errors[:data]).to include(match(/is not a valid permissive_hash/))
    end

    context 'when optional' do
      let(:contract_class) do
        Class.new(ApiContract::Base) do
          attribute :data, :permissive_hash, optional: true
        end
      end

      it 'is valid with nil' do
        contract = contract_class.new(data: nil)
        contract.valid?
        expect(contract.errors[:data]).to be_empty
      end
    end
  end
end
