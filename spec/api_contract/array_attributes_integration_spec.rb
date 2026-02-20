# frozen_string_literal: true

RSpec.describe 'ApiContract::Base array attributes' do # rubocop:disable RSpec/DescribeClass
  describe 'typed arrays with array: option' do
    let(:klass) do
      Class.new(ApiContract::Base) do
        attribute :foods, array: :string
        attribute :counts, array: :integer
      end
    end

    it 'accepts string arrays' do
      contract = klass.new(foods: %w[pizza tacos], counts: [1, 2])
      expect(contract.foods).to eq(%w[pizza tacos])
    end

    it 'coerces integers to strings in string array' do
      contract = klass.new(foods: [1, 2], counts: [1])
      expect(contract.foods).to eq(%w[1 2])
    end

    it 'coerces string elements to integers' do
      contract = klass.new(foods: ['a'], counts: %w[1 2])
      expect(contract.counts).to eq([1, 2])
    end

    it 'does not raise on invalid array elements' do
      expect { klass.new(foods: ['a'], counts: ['a']) }.not_to raise_error
    end

    it 'detects fallback cast in typed integer array via valid?' do
      contract = klass.new(foods: ['a'], counts: ['a'])
      contract.valid?
      expect(contract.errors[:counts]).to include(match(/element at index 0 is not a valid integer/))
    end

    it 'passes validation with genuinely coerced elements' do
      expect(klass.new(foods: %w[a b], counts: %w[1 2])).to be_valid
    end
  end

  describe 'permissive arrays' do
    let(:klass) do
      Class.new(ApiContract::Base) do
        attribute :items, array: :permissive
      end
    end

    it 'accepts mixed types' do
      contract = klass.new(items: [1, nil, { x: 1 }, 'hello'])
      expect(contract.items).to eq([1, nil, { x: 1 }, 'hello'])
    end

    it 'always passes validation' do
      expect(klass.new(items: ['anything'])).to be_valid
    end

    it 'returns nil for nil input' do
      contract = klass.new(items: nil)
      expect(contract.items).to be_nil
    end
  end

  describe 'typed array metadata' do
    let(:klass) do
      Class.new(ApiContract::Base) do
        attribute :foods, array: :string
        attribute :items, array: :permissive
      end
    end

    it 'records :array as the type for typed arrays' do
      expect(klass.attribute_registry[:foods][:type]).to eq(:array)
    end

    it 'records element_type for typed arrays' do
      expect(klass.attribute_registry[:foods][:element_type]).to eq(:string)
    end

    it 'records :array as the type for permissive arrays' do
      expect(klass.attribute_registry[:items][:type]).to eq(:array)
    end

    it 'records :permissive as element_type for permissive arrays' do
      expect(klass.attribute_registry[:items][:element_type]).to eq(:permissive)
    end
  end

  describe 'typed arrays combined with optional and default' do
    let(:klass) do
      Class.new(ApiContract::Base) do
        attribute :tags, array: :string, optional: true, default: []
      end
    end

    it 'applies default when absent' do
      expect(klass.new.tags).to eq([])
    end

    it 'is optional' do
      expect(klass.required_attribute_names).not_to include(:tags)
    end

    it 'uses provided value' do
      expect(klass.new(tags: %w[a b]).tags).to eq(%w[a b])
    end
  end

  describe 'typed array inheritance' do
    let(:parent_class) do
      Class.new(ApiContract::Base) do
        attribute :tags, array: :string
      end
    end

    let(:child_class) do
      Class.new(parent_class) do
        attribute :scores, array: :integer
      end
    end

    it 'inherits typed array attributes' do
      expect(child_class.declared_attribute_names).to include(:tags, :scores)
    end

    it 'casts inherited string array elements' do
      expect(child_class.new(tags: [1], scores: ['5']).tags).to eq(['1'])
    end

    it 'casts child integer array elements' do
      expect(child_class.new(tags: [1], scores: ['5']).scores).to eq([5])
    end

    it 'does not add child attributes to parent' do
      child_class # force evaluation
      expect(parent_class.declared_attribute_names).not_to include(:scores)
    end
  end

  describe 'schema validation with arrays' do
    let(:klass) do
      Class.new(ApiContract::Base) do
        attribute :tags, array: :string
      end
    end

    it 'requires array attributes by default' do
      expect(klass.new.schema_valid?).to be false
    end

    it 'reports missing array attributes' do
      expect(klass.new.schema_errors[:tags]).to eq(['is missing'])
    end

    it 'detects unexpected attributes alongside arrays' do
      expect(klass.new(tags: ['a'], foo: 'bar').schema_errors[:foo]).to eq(['is unexpected'])
    end

    it 'passes with valid array input' do
      expect(klass.new(tags: ['a']).schema_valid?).to be true
    end
  end
end
