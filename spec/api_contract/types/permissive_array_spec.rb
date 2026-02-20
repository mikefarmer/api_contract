# frozen_string_literal: true

RSpec.describe ApiContract::Types::PermissiveArray do
  subject(:type) { described_class.new }

  describe '#cast' do
    it 'returns nil for nil' do
      expect(type.cast(nil)).to be_nil
    end

    it 'returns empty array unchanged' do
      expect(type.cast([])).to eq([])
    end

    it 'passes through arrays unchanged' do
      input = [1, 'two', nil, { x: 3 }]
      expect(type.cast(input)).to eq(input)
    end

    it 'wraps non-array values' do
      expect(type.cast('hello')).to eq(['hello'])
    end

    it 'preserves nested hashes' do
      input = [{ a: 1 }, { b: 2 }]
      expect(type.cast(input)).to eq(input)
    end
  end

  describe '#type' do
    it 'returns :permissive_array' do
      expect(type.type).to eq(:permissive_array)
    end
  end
end
