require 'spec_helper'

describe Manifestly do
  it 'has a version number' do
    expect(Manifestly::VERSION).not_to be nil
  end

  xit 'creates a manifest' do
    allow(Thor::LineEditor).to receive(:readline).and_return('a', '3', 'w', 'test.manifest')

    capture(:stdout) {
      Manifestly::CLI.start(%W[create --search_paths=#{absolutize_gem_path('./spec/fixtures/app_repos')}])
    }
  end
end
