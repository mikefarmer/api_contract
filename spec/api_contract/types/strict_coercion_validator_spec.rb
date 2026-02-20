# frozen_string_literal: true

RSpec.describe ApiContract::Types::StrictCoercionValidator do
  describe '.valid_cast?' do
    context 'with non-string raw values' do
      it 'returns true for integer input' do
        expect(described_class.valid_cast?(42, 42, :integer)).to be true
      end

      it 'returns true for nil input' do
        expect(described_class.valid_cast?(nil, nil, :integer)).to be true
      end

      it 'returns true for float input' do
        expect(described_class.valid_cast?(3.14, 3.14, :float)).to be true
      end
    end

    context 'with :integer type' do
      it 'accepts genuine coercion' do
        expect(described_class.valid_cast?('42', 42, :integer)).to be true
      end

      it 'accepts genuine zero' do
        expect(described_class.valid_cast?('0', 0, :integer)).to be true
      end

      it 'rejects fallback cast to zero' do
        expect(described_class.valid_cast?('a', 0, :integer)).to be false
      end

      it 'rejects empty string fallback' do
        expect(described_class.valid_cast?('', 0, :integer)).to be false
      end

      it 'accepts negative numbers' do
        expect(described_class.valid_cast?('-5', -5, :integer)).to be true
      end
    end

    context 'with :big_integer type' do
      it 'accepts genuine coercion' do
        expect(described_class.valid_cast?('999', 999, :big_integer)).to be true
      end

      it 'rejects fallback cast to zero' do
        expect(described_class.valid_cast?('abc', 0, :big_integer)).to be false
      end
    end

    context 'with :float type' do
      it 'accepts genuine coercion' do
        expect(described_class.valid_cast?('3.14', 3.14, :float)).to be true
      end

      it 'accepts genuine zero string' do
        expect(described_class.valid_cast?('0', 0.0, :float)).to be true
      end

      it 'accepts genuine zero with decimal' do
        expect(described_class.valid_cast?('0.0', 0.0, :float)).to be true
      end

      it 'rejects fallback cast to zero' do
        expect(described_class.valid_cast?('abc', 0.0, :float)).to be false
      end
    end

    context 'with :decimal type' do
      it 'accepts genuine coercion' do
        expect(described_class.valid_cast?('99.99', BigDecimal('99.99'), :decimal)).to be true
      end

      it 'accepts genuine zero' do
        expect(described_class.valid_cast?('0', BigDecimal('0'), :decimal)).to be true
      end

      it 'rejects fallback cast to zero' do
        expect(described_class.valid_cast?('xyz', BigDecimal('0'), :decimal)).to be false
      end
    end

    context 'with :boolean type' do
      %w[true false 1 0 t f T F TRUE FALSE yes no YES NO y n Y N].each do |val|
        it "accepts valid boolean string #{val.inspect}" do
          expect(described_class.valid_cast?(val, nil, :boolean)).to be true
        end
      end

      it 'rejects invalid boolean string' do
        expect(described_class.valid_cast?('garbage', true, :boolean)).to be false
      end

      it 'rejects empty string' do
        expect(described_class.valid_cast?('', nil, :boolean)).to be false
      end
    end

    context 'with :date type' do
      it 'accepts genuine coercion' do
        expect(described_class.valid_cast?('2024-01-15', Date.new(2024, 1, 15), :date)).to be true
      end

      it 'rejects invalid date string' do
        expect(described_class.valid_cast?('garbage', nil, :date)).to be false
      end

      it 'accepts empty string casting to nil' do
        expect(described_class.valid_cast?('', nil, :date)).to be true
      end

      it 'accepts whitespace-only string casting to nil' do
        expect(described_class.valid_cast?('  ', nil, :date)).to be true
      end
    end

    context 'with :datetime type' do
      it 'accepts genuine coercion' do
        expect(described_class.valid_cast?('2024-01-15T10:30:00Z', Time.utc(2024, 1, 15, 10, 30, 0), :datetime))
          .to be true
      end

      it 'rejects invalid datetime string' do
        expect(described_class.valid_cast?('not-a-date', nil, :datetime)).to be false
      end
    end

    context 'with :time type' do
      it 'accepts genuine coercion' do
        expect(described_class.valid_cast?('2024-01-15T10:30:00Z', Time.utc(2024, 1, 15, 10, 30, 0), :time))
          .to be true
      end

      it 'rejects invalid time string' do
        expect(described_class.valid_cast?('not-a-time', nil, :time)).to be false
      end
    end

    context 'with :string type' do
      it 'always returns true' do
        expect(described_class.valid_cast?('anything', 'anything', :string)).to be true
      end
    end

    context 'with :value type' do
      it 'always returns true' do
        expect(described_class.valid_cast?('anything', 'anything', :value)).to be true
      end
    end
  end
end
