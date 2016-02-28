require 'spec_helper'

describe Manifestly::CLI do

  describe 'create' do

    it 'creates a manifest non-interactively' do
      Scenarios.run(inline: <<-SETUP
          mkdir repos && cd repos
          git init -q one
          cd one
          touch some_file
          git add . && git commit -q -m "."
          git rev-parse HEAD > ../../sha_0.txt
          cd ..
          git init -q two
          cd two
          touch other_file
          git add . && git commit -q -m "."
          git rev-parse HEAD > ../../sha_1.txt
        SETUP
      ) do |dirs|
        shas = %w(sha_0 sha_1).collect do |sha|
          File.open("#{dirs[:root]}/#{sha}.txt").read.chomp
        end

        suppress_output do
          Manifestly::CLI.start(%W[create --no-interactive --search_paths=#{dirs[:root]}/repos --add=all --save_as=#{dirs[:root]}/my.manifest])
        end

        manifest = File.open("#{dirs[:root]}/my.manifest").read

        expect(manifest).to eq(
          "one @ #{shas[0]}\n" \
          "two @ #{shas[1]}\n"
        )
      end
    end

  end

  describe '#tag and #find' do

    it 'adds and finds tags on a manifest repository' do
      Scenarios.run(inline: <<-SETUP
        git init -q remote
        cd remote
        touch foo.manifest
        git add . && git commit -q -m "."
        git rev-parse HEAD > ../sha_0.txt
        touch bar.manifest
        git add . && git commit -q -m "."
        git rev-parse HEAD > ../sha_1.txt
        echo blah > foo.manifest
        git add . && git commit -q -m "."
        git rev-parse HEAD > ../sha_2.txt
      SETUP
    ) do |dirs|
        shas = %w(sha_0 sha_1 sha_2).collect do |sha|
          File.open("#{dirs[:root]}/#{sha}.txt").read.chomp
        end

        # Test easy case of one file, one tag

        suppress_output do
          Manifestly::CLI.start(%W[tag --repo=#{dirs[:root]}/remote --sha=#{shas[0]} --tag=release-to-qa --message="howdy"])
        end

        expect(
          Manifestly::CLI.start(%W[find --repo=#{dirs[:root]}/remote --repo_file=foo.manifest --tag=release-to-qa])
        ).to eq [shas[0]]

        # Test can filter based on different file

        suppress_output do
          Manifestly::CLI.start(%W[tag --repo=#{dirs[:root]}/remote --sha=#{shas[1]} --tag=release-to-qa])
        end

        expect(
          Manifestly::CLI.start(%W[find --repo=#{dirs[:root]}/remote --repo_file=bar.manifest --tag=release-to-qa])
        ).to eq [shas[1]]

        suppress_output do
          Manifestly::CLI.start(%W[tag --repo=#{dirs[:root]}/remote --sha=#{shas[2]} --tag=release-to-qa])
        end

        # Test what happens when multiple of "same" tag on one file

        expect(
          Manifestly::CLI.start(%W[find --repo=#{dirs[:root]}/remote --repo_file=foo.manifest --tag=release-to-qa])
        ).to eq [shas[2], shas[0]]

        expect(
          Manifestly::CLI.start(%W[find --repo=#{dirs[:root]}/remote --repo_file=foo.manifest --tag=release-to-qa --limit=3])
        ).to eq [shas[2], shas[0]]

        expect(
          Manifestly::CLI.start(%W[find --repo=#{dirs[:root]}/remote --repo_file=foo.manifest --tag=release-to-qa --limit=1])
        ).to eq [shas[2]]

        # Check that tags made it to remote

        git = Git.open("#{dirs[:root]}/remote")
        expect(git.tags.count).to eq 3
      end
    end

  end

end
