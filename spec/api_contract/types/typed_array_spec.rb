# frozen_string_literal: true

RSpec.describe ApiContract::Types::TypedArray do
  describe '#cast' do
    context 'with integer element type' do
      subject(:type) { described_class.new(element_type: :integer) }

      it 'returns nil for nil' do
        expect(type.cast(nil)).to be_nil
      end

      it 'casts string elements to integers' do
        expect(type.cast(%w[1 2 3])).to eq([1, 2, 3])
      end

      it 'passes through integer elements' do
        expect(type.cast([1, 2, 3])).to eq([1, 2, 3])
      end

      it 'handles empty arrays' do
        expect(type.cast([])).to eq([])
      end

      it 'casts nil elements to nil' do
        expect(type.cast([nil, '1'])).to eq([nil, 1])
      end

      it 'passes through non-array values' do
        expect(type.cast('5')).to eq('5')
      end
    end

    context 'with string element type' do
      subject(:type) { described_class.new(element_type: :string) }

      it 'casts integer elements to strings' do
        expect(type.cast([1, 2, 3])).to eq(%w[1 2 3])
      end
    end
  end

  describe '#element_type_symbol' do
    it 'returns the configured element type' do
      type = described_class.new(element_type: :integer)
      expect(type.element_type_symbol).to eq(:integer)
    end
  end

  describe '#type' do
    it 'returns :array' do
      type = described_class.new(element_type: :string)
      expect(type.type).to eq(:array)
    end
  end
end
