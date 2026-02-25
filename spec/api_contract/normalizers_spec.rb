# frozen_string_literal: true

RSpec.describe ApiContract::Normalizers do
  describe '.normalizes' do
    let(:contract_class) do
      klass = Class.new(ApiContract::Base) do
        attribute :email, :string
        attribute :name, :string

        normalizes :email, with: ->(email) { email.strip.downcase }
      end
      stub_const('NormalizerContract', klass)
    end

    let(:nil_normalizer_class) do
      klass = Class.new(ApiContract::Base) do
        attribute :email, :string, optional: true
        normalizes :email, with: ->(email) { email.strip.downcase }
      end
      stub_const('NilNormalizerContract', klass)
    end

    let(:multi_normalizer_class) do
      klass = Class.new(ApiContract::Base) do
        attribute :first_name, :string
        attribute :last_name, :string
        normalizes :first_name, :last_name, with: :strip.to_proc
      end
      stub_const('MultiNormalizerContract', klass)
    end

    let(:coercion_normalizer_class) do
      klass = Class.new(ApiContract::Base) do
        attribute :code, :string
        normalizes :code, with: :upcase.to_proc
      end
      stub_const('CoercionNormalizerContract', klass)
    end

    let(:child_class) do
      klass = Class.new(contract_class) do
        attribute :phone, :string, optional: true
      end
      stub_const('ChildNormalizerContract', klass)
    end

    it 'transforms attribute values during initialization' do
      contract = contract_class.new(email: '  ALICE@EXAMPLE.COM  ', name: 'Alice')
      expect(contract.email).to eq('alice@example.com')
    end

    it 'does not affect non-normalized attributes' do
      contract = contract_class.new(email: 'a@b.com', name: '  Alice  ')
      expect(contract.name).to eq('  Alice  ')
    end

    it 'skips normalizers for nil values' do
      contract = nil_normalizer_class.new({})
      expect(contract.email).to be_nil
    end

    it 'normalizes first_name with multi-attribute normalizer' do
      contract = multi_normalizer_class.new(first_name: '  Alice  ', last_name: '  Smith  ')
      expect(contract.first_name).to eq('Alice')
    end

    it 'normalizes last_name with multi-attribute normalizer' do
      contract = multi_normalizer_class.new(first_name: '  Alice  ', last_name: '  Smith  ')
      expect(contract.last_name).to eq('Smith')
    end

    it 'runs normalizers after type coercion' do
      contract = coercion_normalizer_class.new(code: 123)
      expect(contract.code).to eq('123')
    end

    it 'normalizers are inherited by subclasses' do
      contract = child_class.new(email: '  BOB@TEST.COM  ', name: 'Bob')
      expect(contract.email).to eq('bob@test.com')
    end
  end

  describe 'callbacks' do
    let(:callback_log) { [] }

    let(:contract_class) do
      log = callback_log
      klass = Class.new(ApiContract::Base) do
        attribute :name, :string
        before_validation { log << :before_validation }
        after_validation { log << :after_validation }
      end
      stub_const('CallbackContract', klass)
    end

    it 'fires before_validation callback' do
      contract_class.new(name: 'Alice').valid?
      expect(callback_log).to include(:before_validation)
    end

    it 'fires after_validation callback' do
      contract_class.new(name: 'Alice').valid?
      expect(callback_log).to include(:after_validation)
    end

    it 'fires callbacks in correct order' do
      contract_class.new(name: 'Alice').valid?
      expect(callback_log).to eq(%i[before_validation after_validation])
    end
  end

  describe 'normalizers + callbacks interaction' do
    let(:norm_callback_class) do
      klass = Class.new(ApiContract::Base) do
        attribute :email, :string
        normalizes :email, with: ->(e) { e.strip.downcase }
      end
      stub_const('NormCallbackContract', klass)
    end

    let(:slug_class) do
      klass = Class.new(ApiContract::Base) do
        attribute :name, :string
        attribute :slug, :string, optional: true

        after_validation :generate_slug

        private

        def generate_slug
          self.slug = name.downcase.gsub(/\s+/, '-') if name
        end
      end
      stub_const('SlugContract', klass)
    end

    it 'normalizers run before validation callbacks' do
      log = []
      norm_callback_class.before_validation { log << email }
      contract = norm_callback_class.new(email: '  ALICE@TEST.COM  ')
      contract.valid?
      expect(log).to eq(['alice@test.com'])
    end

    it 'after_validation can modify mutable contracts' do
      contract = slug_class.new(name: 'Hello World').dup
      contract.valid?
      expect(contract.slug).to eq('hello-world')
    end
  end
end
