# frozen_string_literal: true

RSpec.describe ApiContract::Computed do
  let(:contract_class) do
    klass = Class.new(ApiContract::Base) do
      attribute :first_name, :string
      attribute :last_name, :string
      attribute :full_name, :computed, with: -> { "#{first_name} #{last_name}" }
      attribute :initials, :computed, :build_initials

      private

      def build_initials
        "#{first_name[0]}#{last_name[0]}"
      end
    end
    stub_const('ComputedContract', klass)
  end

  describe 'lambda form' do
    it 'evaluates the lambda at serialization time' do
      contract = contract_class.new(first_name: 'Alice', last_name: 'Smith')
      expect(contract.to_h[:full_name]).to eq('Alice Smith')
    end
  end

  describe 'method name form' do
    it 'calls the named method at serialization time' do
      contract = contract_class.new(first_name: 'Alice', last_name: 'Smith')
      expect(contract.to_h[:initials]).to eq('AS')
    end
  end

  describe 'excluded from deserialization' do
    it 'silently ignores computed attributes in from_params input' do
      contract = contract_class.from_params(first_name: 'Alice', last_name: 'Smith', full_name: 'ignored')
      expect(contract.to_h[:full_name]).to eq('Alice Smith')
    end

    it 'silently ignores computed attributes in from_json input' do
      json = '{"first_name":"Alice","last_name":"Smith","full_name":"ignored"}'
      contract = contract_class.from_json(json)
      expect(contract.to_h[:full_name]).to eq('Alice Smith')
    end

    it 'does not raise UnexpectedAttributeError for computed keys in input' do
      expect { contract_class.from_params(first_name: 'A', last_name: 'B', full_name: 'X') }
        .not_to raise_error
    end
  end

  describe 'excluded from schema validation' do
    it 'never raises MissingAttributeError for computed attributes' do
      contract = contract_class.new(first_name: 'Alice', last_name: 'Smith')
      expect { contract.schema_validate! }.not_to raise_error
    end

    it 'excludes computed attributes from the attributes list' do
      contract = contract_class.new(first_name: 'Alice', last_name: 'Smith')
      expect(contract.attributes).to eq(%i[first_name last_name])
    end
  end

  describe 'included in serialization' do
    let(:contract) do
      contract_class.new(first_name: 'Alice', last_name: 'Smith')
    end

    it 'includes computed values in to_h' do
      expect(contract.to_h).to include(full_name: 'Alice Smith', initials: 'AS')
    end

    it 'includes computed values in as_json' do
      result = contract.as_json
      expect(result).to include('full_name' => 'Alice Smith', 'initials' => 'AS')
    end

    it 'includes computed values in to_json' do
      parsed = JSON.parse(contract.to_json)
      expect(parsed['full_name']).to eq('Alice Smith')
    end

    it 'includes computed values in as_camelcase_json' do
      result = contract.as_camelcase_json
      expect(result).to include('fullName' => 'Alice Smith', 'initials' => 'AS')
    end
  end

  describe 'nil handling' do
    let(:nil_computed_class) do
      klass = Class.new(ApiContract::Base) do
        attribute :name, :string
        attribute :maybe_nil, :computed, with: -> {}
      end
      stub_const('NilComputedContract', klass)
    end

    it 'includes nil computed values in serialization' do
      contract = nil_computed_class.new(name: 'Test')
      expect(contract.to_h).to have_key(:maybe_nil)
    end
  end

  describe 'values method' do
    it 'excludes computed attributes from values' do
      contract = contract_class.new(first_name: 'Alice', last_name: 'Smith')
      expect(contract.values).to eq(%w[Alice Smith])
    end
  end
end
