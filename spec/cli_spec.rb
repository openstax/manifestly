require 'spec_helper'

describe Manifestly::CLI do

  describe 'create' do

    it 'creates a manifest non-interactively' do
      Scenarios.run('create') do |dirs|
        suppress_output do
          Manifestly::CLI.start(%W[create --no-interactive --search_paths=#{dirs[:locals]} --add=all --save_as=#{dirs[:root]}/my.manifest])
        end

        manifest = File.open("#{dirs[:root]}/my.manifest").read

        expect(manifest).to eq(
          "app_repo_1 @ baff0b6df2f5ae88df375c9e3787bf0f95632431\n" \
          "app_repo_2 @ 2ef6871889268957db945fc7e63de553a5ff41d8\n"
        )
      end
    end

  end

  describe 'tag' do

    it 'adds a tag to a manifest repository' do
      Scenarios.run('tag') do |dirs|
        suppress_output do
          Manifestly::CLI.start(%W[tag --repo=#{dirs[:remotes]}/manifest_repo_1 --sha=65cebfae2 --tag=release-to-qa])
        end

        # debugger
        # puts 'hi'

      end
    end

  end

end
