require 'spec_helper'

describe Manifestly::Manifest do

  describe "#get_lines_from_string" do
    it 'should ignore comments and blank lines' do
      input =<<-INPUT
        # a comment followed by a blank line
        \t\t
        foo/bar @ 932938293829382983 # another comment
        bar/foo @ 238928392839283928

        #
      INPUT

      expect(Manifestly::Manifest.get_lines_from_string(input)).to eq ([
        "foo/bar @ 932938293829382983", "bar/foo @ 238928392839283928"
      ])
    end
  end

  describe "create manifest from file" do

    context "old format without repo in manifest" do
      # Somewhat contrived example, b/c a manifest made from this scenario would
      # normally include the repo.

      it 'loads fine' do
        Scenarios.run(inline: <<-SETUP
            mkdir repos && cd repos
            git init -q one
            cd one
            touch some_file
            git add . && git commit -q -m "."
            git remote add origin git@github.com:org/my-repo.git
            git rev-parse HEAD > ../../sha_0.txt
            echo "one @ `git rev-parse HEAD`" > ../../my.manifest
            echo blah > some_file
            git add . && git commit -q -m "."
            git rev-parse HEAD > ../../sha_1.txt
          SETUP
        ) do | dirs|

          repositories = [Manifestly::Repository.load("#{dirs[:root]}/repos/one")]

          expect{
            manifest = described_class.read_file("#{dirs[:root]}/my.manifest", repositories)
          }.not_to raise_error
        end
      end
    end

  end
end
