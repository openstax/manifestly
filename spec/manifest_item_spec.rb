require 'spec_helper'

describe Manifestly::ManifestItem do

  describe "#parse_file_string" do

    context "original style" do
      context "directory present" do
        it "handles spaces" do
          test_parse("org/repo (dir) @ deadbeef", repo: "org/repo", dir: "dir", sha: "deadbeef")
        end

        it "handles no spaces" do
          test_parse("org/repo(dir)@deadbeef", repo: "org/repo", dir: "dir", sha: "deadbeef")
        end

        it "handles comments" do
          test_parse("org/repo(dir)@deadbeef#blah", repo: "org/repo", dir: "dir", sha: "deadbeef")
        end
      end

      context "directory absent" do
        it "handles spaces" do
          test_parse("org/repo    @ deadbeef", repo: "org/repo", dir: "repo", sha: "deadbeef")
        end

        it "handles no spaces" do
          test_parse("org/repo@deadbeef", repo: "org/repo", dir: "repo", sha: "deadbeef")
        end

        it "handles comments" do
          test_parse("org/repo    @ deadbeef #blah ", repo: "org/repo", dir: "repo", sha: "deadbeef")
        end
      end

      context "repo absent" do
        it "handles spaces" do
          test_parse("dir    @ deadbeef", repo: nil, dir: "dir", sha: "deadbeef")
        end

        it "handles no spaces" do
          test_parse("dir@deadbeef", repo: nil, dir: "dir", sha: "deadbeef")
        end

        it "handles comments" do
          test_parse("dir@ deadbeef #blah ", repo: nil, dir: "dir", sha: "deadbeef")
        end
      end
    end

    context "new style" do
      context "repo present" do
        it "works with spaces" do
          test_parse("[directory] org/repo @ deadbeef", repo: "org/repo", dir: "directory", sha: "deadbeef")
        end

        it "works without spaces" do
          test_parse("[directory]org/a-repo@deadbeef", repo: "org/a-repo", dir: "directory", sha: "deadbeef")
        end

        it "works with comments" do
          test_parse("[directory]org/repo@deadbeef # blah", repo: "org/repo", dir: "directory", sha: "deadbeef")
        end
      end

      context "repo absent" do
        it "works with spaces" do
          test_parse("[directory] @ deadbeef", repo: nil, dir: "directory", sha: "deadbeef")
        end

        it "works without spaces" do
          test_parse("[directory]@deadbeef", repo: nil, dir: "directory", sha: "deadbeef")
        end

        it "works with comments" do
          test_parse("[directory] @ deadbeef # blah", repo: nil, dir: "directory", sha: "deadbeef")
        end
      end
    end

  end

  def test_parse(string, repo:, dir:, sha:)
    expect(described_class.parse_file_string(string)).to eq [repo, dir, sha]
  end
end
