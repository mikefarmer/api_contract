# frozen_string_literal: true

RSpec.describe 'ApiContract::Base UUID attributes' do
  # All sample UUIDs live in one memoized helper so individual example
  # groups stay under the memoized-helper cap.
  let(:uuids) do
    {
      v1: '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
      v4: 'f47ac10b-58cc-4372-a567-0e02b2c3d479',
      v6: '1ec9414c-232a-6b00-b3c8-9f6bdeced846',
      v7: '018f6c9e-bb20-7b9e-a6a9-3f3b0c7c4b1f',
      v8: '320c3d4d-cc00-8875-b63e-6874d4b90b57'
    }
  end

  describe 'version-agnostic :uuid' do
    let(:klass) { Class.new(ApiContract::Base) { attribute :id, :uuid } }

    it 'accepts a canonical UUID' do
      expect(klass.new(id: uuids[:v4])).to be_valid
    end

    it 'normalizes uppercase input to lowercase' do
      contract = klass.new(id: 'F47AC10B-58CC-4372-A567-0E02B2C3D479')
      expect(contract.id).to eq(uuids[:v4])
    end

    it 'accepts every RFC 9562 version' do
      aggregate_failures do
        uuids.each do |label, uuid|
          expect(klass.new(id: uuid)).to be_valid, "expected #{label} (#{uuid}) to be valid"
        end
      end
    end

    it 'accepts the nil UUID' do
      expect(klass.new(id: '00000000-0000-0000-0000-000000000000')).to be_valid
    end

    it 'accepts the max UUID' do
      expect(klass.new(id: 'ffffffff-ffff-ffff-ffff-ffffffffffff')).to be_valid
    end

    it 'marks a malformed UUID string as invalid' do
      expect(klass.new(id: 'not-a-uuid')).not_to be_valid
    end

    it 'reports a uuid-specific error for a malformed string' do
      contract = klass.new(id: 'not-a-uuid')
      contract.valid?
      expect(contract.errors[:id]).to include(match(/is not a valid uuid/))
    end

    it 'rejects a non-string value' do
      expect(klass.new(id: 42)).not_to be_valid
    end

    it 'reports a uuid-specific error for a non-string value' do
      contract = klass.new(id: 42)
      contract.valid?
      expect(contract.errors[:id]).to include(match(/is not a valid uuid/))
    end

    it 'rejects an empty string' do
      expect(klass.new(id: '')).not_to be_valid
    end

    it 'rejects nil for a required attribute via schema validation' do
      expect { klass.from_params({}) }.to raise_error(ApiContract::MissingAttributeError)
    end
  end

  describe 'optional :uuid' do
    let(:klass) { Class.new(ApiContract::Base) { attribute :id, :uuid, optional: true } }

    it 'allows nil' do
      expect(klass.new(id: nil)).to be_valid
    end

    it 'still rejects a malformed string' do
      expect(klass.new(id: 'nope')).not_to be_valid
    end
  end

  describe 'version-specific :uuid_v4' do
    let(:klass) { Class.new(ApiContract::Base) { attribute :id, :uuid_v4 } }

    it 'accepts a v4 UUID' do
      expect(klass.new(id: uuids[:v4])).to be_valid
    end

    it 'rejects a v7 UUID' do
      expect(klass.new(id: uuids[:v7])).not_to be_valid
    end

    it 'reports a uuid_v4-specific error for a wrong-version UUID' do
      contract = klass.new(id: uuids[:v7])
      contract.valid?
      expect(contract.errors[:id]).to include(match(/is not a valid uuid_v4/))
    end

    it 'rejects the nil UUID' do
      expect(klass.new(id: '00000000-0000-0000-0000-000000000000')).not_to be_valid
    end
  end

  describe 'version-specific :uuid_v7 round-trip' do
    let(:klass) { Class.new(ApiContract::Base) { attribute :id, :uuid_v7 } }

    it 'accepts a v7 UUID' do
      expect(klass.new(id: uuids[:v7])).to be_valid
    end

    it 'rejects a v4 UUID' do
      expect(klass.new(id: uuids[:v4])).not_to be_valid
    end
  end

  describe 'v1 coverage' do
    it 'accepts a v1 UUID for :uuid_v1' do
      klass = Class.new(ApiContract::Base) { attribute :id, :uuid_v1 }
      expect(klass.new(id: uuids[:v1])).to be_valid
    end
  end

  describe 'v6 coverage' do
    it 'accepts a v6 UUID for :uuid_v6' do
      klass = Class.new(ApiContract::Base) { attribute :id, :uuid_v6 }
      expect(klass.new(id: uuids[:v6])).to be_valid
    end
  end

  describe 'v8 coverage' do
    it 'accepts a v8 UUID for :uuid_v8' do
      klass = Class.new(ApiContract::Base) { attribute :id, :uuid_v8 }
      expect(klass.new(id: uuids[:v8])).to be_valid
    end
  end

  describe 'arrays of UUIDs' do
    let(:klass) { Class.new(ApiContract::Base) { attribute :ids, array: :uuid } }

    it 'accepts an array of valid UUIDs' do
      expect(klass.new(ids: [uuids[:v1], uuids[:v4], uuids[:v7]])).to be_valid
    end

    it 'normalizes elements to lowercase' do
      contract = klass.new(ids: [uuids[:v4].upcase])
      expect(contract.ids).to eq([uuids[:v4]])
    end

    it 'rejects an element that is not a valid UUID' do
      expect(klass.new(ids: [uuids[:v4], 'bad'])).not_to be_valid
    end

    it 'reports an indexed uuid error for a bad element' do
      contract = klass.new(ids: [uuids[:v4], 'bad'])
      contract.valid?
      expect(contract.errors[:ids]).to include(match(/element at index 1 is not a valid uuid/))
    end
  end

  describe 'arrays of version-specific UUIDs' do
    let(:klass) { Class.new(ApiContract::Base) { attribute :ids, array: :uuid_v7 } }

    it 'accepts v7 elements' do
      expect(klass.new(ids: [uuids[:v7]])).to be_valid
    end

    it 'rejects a v4 element' do
      expect(klass.new(ids: [uuids[:v7], uuids[:v4]])).not_to be_valid
    end

    it 'reports a uuid_v7-specific error for a wrong-version element' do
      contract = klass.new(ids: [uuids[:v7], uuids[:v4]])
      contract.valid?
      expect(contract.errors[:ids]).to include(match(/element at index 1 is not a valid uuid_v7/))
    end
  end

  describe 'OpenAPI schema output' do
    it 'emits type: string, format: uuid for :uuid' do
      klass = Class.new(ApiContract::Base) { attribute :id, :uuid }
      expect(klass.open_api_schema['properties']['id'])
        .to eq({ 'type' => 'string', 'format' => 'uuid' })
    end

    it 'adds a version-specific pattern for :uuid_v4' do
      klass = Class.new(ApiContract::Base) { attribute :id, :uuid_v4 }
      pattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
      expect(klass.open_api_schema['properties']['id'])
        .to eq('type' => 'string', 'format' => 'uuid', 'pattern' => pattern)
    end

    it 'emits uuid schema for array items' do
      klass = Class.new(ApiContract::Base) { attribute :ids, array: :uuid }
      expect(klass.open_api_schema['properties']['ids']).to eq(
        'type' => 'array',
        'items' => { 'type' => 'string', 'format' => 'uuid' }
      )
    end

    it 'emits version-specific uuid schema for array items' do
      klass = Class.new(ApiContract::Base) { attribute :ids, array: :uuid_v7 }
      expect(klass.open_api_schema['properties']['ids']['items']['pattern'])
        .to include('-7[0-9a-fA-F]{3}')
    end
  end
end
