# frozen_string_literal: true

RSpec.describe 'ApiContract::Base strict coercion' do # rubocop:disable RSpec/DescribeClass
  describe 'scalar attributes' do
    describe 'integer attributes' do
      let(:klass) { Class.new(ApiContract::Base) { attribute :age, :integer } }

      it 'accepts genuine coercion as valid' do
        contract = klass.new(age: '42')
        expect(contract).to be_valid
      end

      it 'coerces genuine string to integer' do
        contract = klass.new(age: '42')
        expect(contract.age).to eq(42)
      end

      it 'marks fallback cast as invalid' do
        contract = klass.new(age: 'a')
        expect(contract).not_to be_valid
      end

      it 'reports error for fallback cast' do
        contract = klass.new(age: 'a')
        contract.valid?
        expect(contract.errors[:age]).to include(match(/is not a valid integer/))
      end

      it 'accepts non-string values without validation error' do
        contract = klass.new(age: 42)
        expect(contract).to be_valid
      end

      it 'does not raise on construction with invalid input' do
        expect { klass.new(age: 'a') }.not_to raise_error
      end
    end

    describe 'float attributes' do
      let(:klass) { Class.new(ApiContract::Base) { attribute :score, :float } }

      it 'accepts genuine coercion' do
        expect(klass.new(score: '3.14')).to be_valid
      end

      it 'marks fallback cast as invalid' do
        expect(klass.new(score: 'a')).not_to be_valid
      end

      it 'reports error for fallback cast' do
        contract = klass.new(score: 'a')
        contract.valid?
        expect(contract.errors[:score]).to include(match(/is not a valid float/))
      end
    end

    describe 'decimal attributes' do
      let(:klass) { Class.new(ApiContract::Base) { attribute :amount, :decimal } }

      it 'accepts genuine coercion' do
        expect(klass.new(amount: '99.99')).to be_valid
      end

      it 'marks fallback cast as invalid' do
        expect(klass.new(amount: 'xyz')).not_to be_valid
      end
    end

    describe 'boolean attributes' do
      let(:klass) { Class.new(ApiContract::Base) { attribute :active, :boolean } }

      it 'accepts valid boolean strings' do
        %w[true false 1 0 t f yes no].each do |val|
          expect(klass.new(active: val)).to be_valid, "Expected #{val.inspect} to be valid"
        end
      end

      it 'marks invalid boolean string as invalid' do
        expect(klass.new(active: 'garbage')).not_to be_valid
      end

      it 'reports error for invalid boolean' do
        contract = klass.new(active: 'garbage')
        contract.valid?
        expect(contract.errors[:active]).to include(match(/is not a valid boolean/))
      end
    end

    describe 'date attributes' do
      let(:klass) { Class.new(ApiContract::Base) { attribute :born, :date } }

      it 'accepts genuine coercion' do
        expect(klass.new(born: '2024-01-15')).to be_valid
      end

      it 'marks invalid date as invalid' do
        expect(klass.new(born: 'garbage')).not_to be_valid
      end
    end

    describe 'datetime attributes' do
      let(:klass) { Class.new(ApiContract::Base) { attribute :at, :datetime } }

      it 'accepts genuine coercion' do
        expect(klass.new(at: '2024-01-15T10:30:00Z')).to be_valid
      end

      it 'marks invalid datetime as invalid' do
        expect(klass.new(at: 'not-a-date')).not_to be_valid
      end
    end

    describe 'string attributes' do
      let(:klass) { Class.new(ApiContract::Base) { attribute :name, :string } }

      it 'never fails strict coercion' do
        expect(klass.new(name: 'anything')).to be_valid
      end
    end

    describe 'existing coercion tests still pass' do
      it 'coerces integer genuinely and is valid' do
        klass = Class.new(ApiContract::Base) { attribute :val, :integer }
        expect(klass.new(val: '42')).to be_valid
      end

      it 'coerces float genuinely and is valid' do
        klass = Class.new(ApiContract::Base) { attribute :val, :float }
        expect(klass.new(val: '3.14')).to be_valid
      end

      it 'coerces boolean genuinely and is valid' do
        klass = Class.new(ApiContract::Base) { attribute :val, :boolean }
        expect(klass.new(val: '1')).to be_valid
      end
    end
  end
end
