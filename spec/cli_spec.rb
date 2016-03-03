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

  describe "#diff" do
    it 'works' do
      Scenarios.run(inline: <<-SETUP
          git init -q one
          fake_commit | repo:one | comment: A non-PR commit
          fake_commit | repo:one | comment: A non-PR commit | sha:SHA1
          fake_commit | repo:one | comment: Merge pull request #1 from org/branch1 Added import ability
          fake_commit | repo:one | comment: Another commit
          fake_commit | repo:one | comment: Merge pull request #2 from org/branch2 Added feature Y | sha:SHA5
          git init -q two
          fake_commit | repo:two | comment: Merge pull request #54 from org/blahdeblah Fixed bug blah | sha:SHA2
          fake_commit | repo:two | comment: Some commit | sha:SHA3
          git init -q three
          fake_commit | repo:three | comment:Blah | sha:SHA4
          git init -q four
          fake_commit | repo:four | comment: Merge pull request #23 from org/yaya Added cookie ability | sha:SHA6
          fake_commit | repo:four | comment: Another commit
          fake_commit | repo:four | comment: Merge pull request #24 from org/howdy Added milkshakes
          fake_commit | repo:four | comment: Merge pull request #25 from org/howdy Added feature WW | sha:SHA7
          git init -q manifests
          cd manifests
          echo one @ "${SHA1}" >> foo
          echo two @ "${SHA2}" >> foo
          echo four @ "${SHA7}" >> foo
          git add . && git commit -q -m "."
          git rev-parse HEAD > ../manifest_0_sha.txt
          echo one @ "${SHA5}" > foo
          echo two @ "${SHA3}" >> foo
          echo three @ "${SHA4}" >> foo
          echo four @ "${SHA6}" >> foo
          git add . && git commit -q -m "."
          git rev-parse HEAD > ../manifest_1_sha.txt
        SETUP
      ) do |dirs|
        manifest_shas = %w(0 1).collect do |sha|
          File.open("#{dirs[:root]}/manifest_#{sha}_sha.txt").read.chomp
        end

        result = Manifestly::CLI.start(%W[diff --search_paths=#{dirs[:root]} --repo=#{dirs[:root]}/manifests --from_sha=#{manifest_shas[0]} --to_sha=#{manifest_shas[1]}])

        expect(result).to match /Manifest Diff\n\n.*foo.*manifests.*\n\n## one.*\n\n.*PR #2 Added.*\n.*PR #1.*\n\n## two.*\n\n\* There.*\n\n## three.*\n\n\* This.*\n\n## four.*\n\n.*rolled back.*\n\n.*\[PR #25.*\n.*PR #24.*/
      end

    end
  end

end
