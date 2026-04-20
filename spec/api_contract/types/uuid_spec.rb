# frozen_string_literal: true

RSpec.describe ApiContract::Types::UUID do
  # Representative valid samples for each RFC 9562 version, with the
  # required version nibble (13th hex char) and variant bits
  # (17th hex char in [89ab]).
  let(:version_samples) do
    {
      1 => '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
      2 => '000003e8-9dad-21d1-a800-00c04fd430c8',
      3 => '6fa459ea-ee8a-3ca4-894e-db77e160355e',
      4 => 'f47ac10b-58cc-4372-a567-0e02b2c3d479',
      5 => '886313e1-3b8a-5372-9b90-0c9aee199e5d',
      6 => '1ec9414c-232a-6b00-b3c8-9f6bdeced846',
      7 => '018f6c9e-bb20-7b9e-a6a9-3f3b0c7c4b1f',
      8 => '320c3d4d-cc00-8875-b63e-6874d4b90b57'
    }
  end

  describe '#cast' do
    context 'with default (version-agnostic)' do
      subject(:type) { described_class.new }

      it 'returns nil for nil' do
        expect(type.cast(nil)).to be_nil
      end

      it 'returns a lowercase copy of a canonical UUID' do
        expect(type.cast('F47AC10B-58CC-4372-A567-0E02B2C3D479'))
          .to eq('f47ac10b-58cc-4372-a567-0e02b2c3d479')
      end

      it 'accepts the nil UUID' do
        expect(type.cast('00000000-0000-0000-0000-000000000000'))
          .to eq('00000000-0000-0000-0000-000000000000')
      end

      it 'accepts the max UUID' do
        expect(type.cast('FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF'))
          .to eq('ffffffff-ffff-ffff-ffff-ffffffffffff')
      end

      it 'accepts every RFC 9562 version' do
        version_samples.each_value do |sample|
          expect(type.cast(sample)).to eq(sample)
        end
      end

      it 'passes through invalid strings unchanged' do
        expect(type.cast('not-a-uuid')).to eq('not-a-uuid')
      end

      it 'passes through empty strings unchanged' do
        expect(type.cast('')).to eq('')
      end

      it 'passes through non-string values unchanged' do
        expect(type.cast(42)).to eq(42)
      end
    end

    context 'with version-specific types' do
      (1..8).each do |version|
        it "normalizes a matching v#{version} UUID" do
          type = described_class.new(version: version)
          expect(type.cast(version_samples[version].upcase))
            .to eq(version_samples[version])
        end

        it "passes through a UUID of the wrong version unchanged when version is #{version}" do
          mismatched_version = version == 4 ? 7 : 4
          type = described_class.new(version: version)
          sample = version_samples[mismatched_version]
          expect(type.cast(sample)).to eq(sample)
        end
      end

      it 'passes through nil UUID for version-specific types' do
        type = described_class.new(version: 4)
        expect(type.cast('00000000-0000-0000-0000-000000000000'))
          .to eq('00000000-0000-0000-0000-000000000000')
      end
    end
  end

  describe '.regex_for' do
    it 'returns UUID_REGEX when version is nil' do
      expect(described_class.regex_for(nil)).to eq(described_class::UUID_REGEX)
    end

    (1..8).each do |version|
      it "matches a v#{version} UUID with a v#{version} regex" do
        expect(described_class.regex_for(version)).to match(version_samples[version])
      end

      next if version == 4

      it "does not match a v4 UUID with a v#{version} regex" do
        expect(described_class.regex_for(version)).not_to match(version_samples[4])
      end
    end

    it 'enforces RFC 9562 variant bits' do
      bad_variant = 'f47ac10b-58cc-4372-c567-0e02b2c3d479' # 'c' is not in [89ab]
      expect(described_class.regex_for(4)).not_to match(bad_variant)
    end
  end

  describe '#type' do
    it 'returns :uuid when no version is given' do
      expect(described_class.new.type).to eq(:uuid)
    end

    (1..8).each do |version|
      it "returns :uuid_v#{version} for version #{version}" do
        expect(described_class.new(version: version).type).to eq(:"uuid_v#{version}")
      end
    end
  end

  describe '#initialize' do
    it 'rejects a version below the supported range' do
      expect { described_class.new(version: 0) }.to raise_error(ArgumentError)
    end

    it 'rejects a version above the supported range' do
      expect { described_class.new(version: 9) }.to raise_error(ArgumentError)
    end

    it 'rejects non-integer versions' do
      expect { described_class.new(version: '4') }.to raise_error(ArgumentError)
    end
  end
end
