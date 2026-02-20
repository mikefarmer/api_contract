# frozen_string_literal: true

RSpec.describe ApiContract do
  describe 'VERSION' do
    it 'is a semver string' do
      expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
