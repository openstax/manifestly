require 'spec_helper'

describe Manifestly::CLI do

  describe 'apply' do

    it 'applies when no update needed' do
      Scenarios.run(inline: <<-SETUP
          mkdir repos && cd repos
          git init -q one
          cd one
          touch some_file
          git add . && git commit -q -m "."
          git rev-parse HEAD > ../../sha_0.txt
          echo "one @ `git rev-parse HEAD | cut -c1-10`" > ../../my.manifest
          echo blah > some_file
          git add . && git commit -q -m "."
          git rev-parse HEAD > ../../sha_1.txt
        SETUP
      ) do | dirs|

        shas = %w(sha_0 sha_1).collect do |sha|
          File.open("#{dirs[:root]}/#{sha}.txt").read.chomp
        end

        # Repo "one" is at latest SHA
        expect(`cd #{dirs[:root]}/repos/one\n git rev-parse HEAD`.chomp).to eq shas[1]

        suppress_output do
          Manifestly::CLI.start(%W[apply --search_paths=#{dirs[:root]}/repos --file=#{dirs[:root]}/my.manifest])
        end

        # After applying manifest, repo "one" is at the earlier SHA
        expect(`cd #{dirs[:root]}/repos/one\n git rev-parse HEAD`.chomp).to eq shas[0]
      end
    end

    context "when local repository is out of date" do
      around(:each) do |example|
        Scenarios.run(inline: <<-SETUP
            mkdir remote && mkdir local

            cd remote
            git init -q one
            fake_commit | repo:one | comment: first commit| sha:SHA0

            cd ../local
            git clone -q ../remote/one

            cd ../remote
            fake_commit | repo:one | comment: second commit not in local | sha:SHA1

            cd ..
            echo "${SHA0}" > sha_0.txt
            echo "${SHA1}" > sha_1.txt
            echo one @ "${SHA1}" \\# test comment ability >> my.manifest
          SETUP
        ) do |dirs|
          @shas = %w(sha_0 sha_1).collect do |sha|
            File.open("#{dirs[:root]}/#{sha}.txt").read.chomp
          end
          @dirs = dirs

          example.run
        end
      end

      it "works if --update specified" do
        # Repo "one" is at latest SHA
        expect(`cd #{@dirs[:root]}/local/one\n git rev-parse HEAD`.chomp).to eq @shas[0]

        suppress_output do
          Manifestly::CLI.start(%W[apply --update --search_paths=#{@dirs[:root]}/local --file=#{@dirs[:root]}/my.manifest])
        end

        # After applying manifest, repo "one" is at the earlier SHA
        expect(`cd #{@dirs[:root]}/local/one\n git rev-parse HEAD`.chomp).to eq @shas[1]
      end

      it "errors if --update is not specified" do
        # Repo "one" is at latest SHA
        expect(`cd #{@dirs[:root]}/local/one\n git rev-parse HEAD`.chomp).to eq @shas[0]

        expect{
          Manifestly::CLI.start(%W[apply --search_paths=#{@dirs[:root]}/local --file=#{@dirs[:root]}/my.manifest])
        }.to exit_with_message(/Try running again with the `--update` option./)

        # SHA unchanged
        expect(`cd #{@dirs[:root]}/local/one\n git rev-parse HEAD`.chomp).to eq @shas[0]
      end
    end

  end

  describe 'create' do

    it 'exits with non-zero status on errors' do
      expect{ Manifestly::CLI.start(%W[download]) }.to exit_with_message(/No value provided for required options/)
    end

    context 'non-interactive creation' do
      around(:each) do |example|
          Scenarios.run(inline: <<-SETUP
            mkdir repos && cd repos
            git init -q one
            cd one
            git remote add origin https://github.com/org/repo.git
            touch some_file
            git add . && git commit -q -m "."
            git rev-parse HEAD > ../../sha_0.txt
            cd ..
            git init -q two
            cd two
            touch other_file
            git add . && git commit -q -m "."
            git tag -a v8.7 -m "howdy"
            git rev-parse HEAD > ../../sha_1.txt
            cd ..
            git init -q three
            cd three
            git remote add origin git@github.com:org/repo2.git
            touch some_file
            git add . && git commit -q -m "."
            git tag v1.2.3
            git rev-parse HEAD > ../../sha_2.txt
          SETUP
        ) do |dirs|
          @shas = %w(sha_0 sha_1 sha_2).collect do |sha|
            File.open("#{dirs[:root]}/#{sha}.txt").read.chomp
          end
          @dirs = dirs

          example.run
        end
      end

      it 'creates a manifest with default options' do
        suppress_output do
          Manifestly::CLI.start(%W[create --no-interactive --search_paths=#{@dirs[:root]}/repos --add=all --save_as=#{@dirs[:root]}/my.manifest])
        end

        manifest = File.open("#{@dirs[:root]}/my.manifest").read

        expect(manifest).to eq(
          "[one] org/repo@#{std_sha(@shas[0])}\n" \
          "[three] org/repo2@#{std_sha(@shas[2])} # v1.2.3\n" \
          "[two]@#{std_sha(@shas[1])}\n"
        )
      end

      it 'creates a manifest with full SHAs' do
        suppress_output do
          Manifestly::CLI.start(%W[create --no-interactive --search_paths=#{@dirs[:root]}/repos --add=all --save_as=#{@dirs[:root]}/my.manifest --full-shas=true])
        end

        manifest = File.open("#{@dirs[:root]}/my.manifest").read

        expect(manifest).to eq(
          "[one] org/repo@#{@shas[0]}\n" \
          "[three] org/repo2@#{@shas[2]} # v1.2.3\n" \
          "[two]@#{@shas[1]}\n"
        )
      end

    end
  end

  describe "upload" do

    it "uploads and returns the SHA" do
      Scenarios.run(inline: <<-SETUP
          git init -q remote
          cd remote
          touch file.txt
          git add . && git commit -q -m "."
          cd ..
          git clone -q --bare -l remote remote.git
          rm -rf remote
          git clone -q remote.git local
          touch another_file.txt
          echo blah > another_file.txt
        SETUP
      ) do |dirs|

        manifest_sha = capture(:stdout) {
          Manifestly::CLI.start(%W[upload --file=#{dirs[:root]}/another_file.txt --repo=#{dirs[:root]}/remote.git --repo-file=file.txt --message=howdy])
        }
        expect(`cd #{dirs[:root]}/remote.git\n git show HEAD:file.txt`).to eq "blah\n"
        expect(`cd #{dirs[:root]}/remote.git\n git show`).to match /commit #{manifest_sha}/
      end
    end

    it "can upload to a non-existing repo file" do
      Scenarios.run(inline: <<-SETUP
          git init -q remote
          cd remote
          touch file.txt
          git add . && git commit -q -m "."
          cd ..
          git clone -q --bare -l remote remote.git
          rm -rf remote
          git clone -q remote.git local
          touch another_file.txt
          echo blah > another_file.txt
        SETUP
      ) do |dirs|

        manifest_sha = capture(:stdout) {
          Manifestly::CLI.start(%W[upload --file=#{dirs[:root]}/another_file.txt --repo=#{dirs[:root]}/remote.git --repo-file=new_remote_file --message=howdy])
        }

        expect(manifest_sha.strip).to match /[0-9a-f]{40}/
      end
    end

    it "can report a SHA when a manifest being uploaded hasn't changed" do
      Scenarios.run(inline: <<-SETUP
          git init -q remote
          cd remote
          touch file.txt
          git add . && git commit -q -m "."
          cd ..
          git clone -q --bare -l remote remote.git
          rm -rf remote
          git clone -q remote.git local
          touch another_file.txt
          echo blah > another_file.txt
        SETUP
      ) do |dirs|

        manifest_sha = capture(:stdout) {
          Manifestly::CLI.start(%W[upload --file=#{dirs[:root]}/another_file.txt --repo=#{dirs[:root]}/remote.git --repo-file=file.txt --message=howdy])
        }

        expect(manifest_sha.strip).to match /[0-9a-f]{40}/


        manifest_sha_2 = capture(:stdout) {
          Manifestly::CLI.start(%W[upload --file=#{dirs[:root]}/another_file.txt --repo=#{dirs[:root]}/remote.git --repo-file=file.txt --message=howdy])
        }

        expect(manifest_sha_2).to eq manifest_sha
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

        expect(capture(:stdout) {
          Manifestly::CLI.start(%W[find --repo=#{dirs[:root]}/remote --repo_file=foo.manifest --tag=release-to-qa])
        }.chomp).to eq shas[0]

        # Test can filter based on different file

        suppress_output do
          Manifestly::CLI.start(%W[tag --repo=#{dirs[:root]}/remote --sha=#{shas[1]} --tag=release-to-qa])
        end

        expect(capture(:stdout) {
          Manifestly::CLI.start(%W[find --repo=#{dirs[:root]}/remote --repo_file=bar.manifest --tag=release-to-qa])
        }.chomp).to eq shas[1]

        suppress_output do
          Manifestly::CLI.start(%W[tag --repo=#{dirs[:root]}/remote --sha=#{shas[2]} --tag=release-to-qa])
        end

        # Test what happens when multiple of "same" tag on one file

        expect(capture(:stdout) {
          Manifestly::CLI.start(%W[find --repo=#{dirs[:root]}/remote --repo_file=foo.manifest --tag=release-to-qa])
        }.chomp).to eq [shas[2], shas[0]].join("\n")

        expect(capture(:stdout) {
          Manifestly::CLI.start(%W[find --repo=#{dirs[:root]}/remote --repo_file=foo.manifest --tag=release-to-qa --limit=3])
        }.chomp).to eq [shas[2], shas[0]].join("\n")

        expect(capture(:stdout) {
          Manifestly::CLI.start(%W[find --repo=#{dirs[:root]}/remote --repo_file=foo.manifest --tag=release-to-qa --limit=1])
        }.chomp).to eq shas[2]

        # Check that tags made it to remote; there should be 3 unique tags, and each file has one plain tag
        # for a total of 5

        git = Git.open("#{dirs[:root]}/remote")
        expect(git.tags.count).to eq 5
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
          cd four
          git remote add origin git@github.com:org/repo2.git
          cd ..
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

        expect(result).to match /Manifest Diff\n\n.*foo.*manifests.*\n\n## \[one.*\n\n.*PR #2 Added.*\n.*PR #1.*\n\n## \[two.*\n\n\* There.*\n\n## \[three.*\n\n\* This.*\n\n## \[four\] org\/repo2.*\n\n.*rolled back.*\n\n.*\[PR #25.*\n.*PR #24.*/
      end

    end
  end

  describe "upload, tag, and find" do
    it "uploads and returns the SHA" do
      Scenarios.run(inline: <<-SETUP
          git init -q remote
          cd remote
          touch file.txt
          git add . && git commit -q -m "."
          cd ..
          git clone -q --bare -l remote remote.git
          rm -rf remote
          git clone -q remote.git local
          touch another_file.txt
          echo blah > another_file.txt
        SETUP
      ) do |dirs|

        manifest_sha = capture(:stdout) {
          Manifestly::CLI.start(%W[upload --file=#{dirs[:root]}/another_file.txt --repo=#{dirs[:root]}/remote.git --repo-file=foo.manifest --message=howdy])
        }

        suppress_output do
          Manifestly::CLI.start(%W[tag --repo=#{dirs[:root]}/remote.git --sha=#{manifest_sha} --tag=release-to-qa --message="hi\ there"])
        end

        expect(
          capture(:stdout) {
            Manifestly::CLI.start(%W[find --repo=#{dirs[:root]}/remote.git --repo_file=foo.manifest --tag=release-to-qa])
          }
        ).to eq manifest_sha

        # do it again to show that the duplicate tag doesn't stick (no error output and still just "one" tag,
        # really there is a plain version and a unique version so the tag count should be 2)

        expect(capture(:stdout) {
          Manifestly::CLI.start(%W[tag --repo=#{dirs[:root]}/remote.git --sha=#{manifest_sha} --tag=release-to-qa --message="hi\ there"])
        }).to eq ""

        expect(Git.ls_remote("#{dirs[:root]}/remote.git")["tags"].keys.reject{|kk| kk.match(/.*\^\{\}/)}.count).to eq 2
      end
    end
  end

end
