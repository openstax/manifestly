require 'spec_helper'

describe Manifestly::Repository do

  it 'should get github_name_or_path for ssh clone repos' do
    origin = instance_double("Git::Remote", url: "git@github.com:organization/reponame.git")
    expect_any_instance_of(Manifestly::Repository).to receive(:origin).and_return(origin, origin)
    expect(Manifestly::Repository.new('').github_name_or_path).to eq "organization/reponame"
  end

  it 'should get github_name_or_path for http cloned repos' do
    origin = instance_double("Git::Remote", url: "http://github.com/organization/reponame")
    expect_any_instance_of(Manifestly::Repository).to receive(:origin).and_return(origin, origin)
    expect(Manifestly::Repository.new('').github_name_or_path).to eq "organization/reponame"
  end

  it 'should get github_name_or_path for httpS cloned repos' do
    origin = instance_double("Git::Remote", url: "https://github.com/organization/reponame")
    expect_any_instance_of(Manifestly::Repository).to receive(:origin).and_return(origin, origin)
    expect(Manifestly::Repository.new('').github_name_or_path).to eq "organization/reponame"
  end

  it 'should get the right file for a given commit' do
    Scenarios.run(inline: <<-SETUP
        git init -q repo
        cd repo
        echo apple > apple.txt
        git add . && git commit -q -m "."
        git rev-parse HEAD > ../a_sha.txt
        echo banana > banana.txt
        git add . && git commit -q -m "."
        git rev-parse HEAD > ../b_sha.txt
        echo carrot > carrot.txt
        git add . && git commit -q -m "."
      SETUP
    ) do |dirs|
      a_sha = File.open("#{dirs[:root]}/a_sha.txt").read.chomp
      b_sha = File.open("#{dirs[:root]}/b_sha.txt").read.chomp

      repo = Manifestly::Repository.load("#{dirs[:root]}/repo")

      file = repo.get_commit_file(b_sha)
      expect(file.to_name).to eq 'banana.txt'
      expect(file.to_content).to eq 'banana'

      file = repo.get_commit_file(a_sha)
      expect(file.to_name).to eq 'apple.txt'
      expect(file.to_content).to eq 'apple'
    end
  end

  it 'should tag scoped to a file' do
    Scenarios.run(inline: <<-SETUP
        git init -q remote
        cd remote
        touch file.txt
        git add . && git commit -q -m "."
        cd ..
        git clone -q remote local
        cd local
        git rev-parse HEAD > ../sha.txt
      SETUP
    ) do |dirs|
      sha = File.open("#{dirs[:root]}/sha.txt").read.chomp
      local = Manifestly::Repository.load("#{dirs[:root]}/local")
      local.tag_scoped_to_file(tag: 'release-to-qa', sha: sha, message: 'hi', push: true)

      remote = Git.open("#{dirs[:root]}/remote")
      expect(remote.describe(sha)).to match /.+\/release-to-qa/
    end
  end

  it 'should return ordered shas tag / file combinations' do
    Scenarios.run(inline: <<-SETUP
        git init -q repo
        cd repo
        touch file.txt
        git add . && git commit -q -m "."
        git rev-parse HEAD > ../sha_1.txt
        touch other.txt
        git add . && git commit -q -m "."
        git rev-parse HEAD > ../sha_2.txt
        echo blah > file.txt
        git add . && git commit -q -m "."
        git rev-parse HEAD > ../sha_3.txt
      SETUP
    ) do |dirs|
      shas = %w(sha_1 sha_2 sha_3).collect do |sha|
        File.open("#{dirs[:root]}/#{sha}.txt").read.chomp
      end

      repo = Manifestly::Repository.load("#{dirs[:root]}/repo")
      repo.tag_scoped_to_file(tag: 'release-to-qa', sha: shas[0], message: 'hi')
      repo.tag_scoped_to_file(tag: 'release-to-qa', sha: shas[1], message: 'howdy')
      repo.tag_scoped_to_file(tag: 'release-to-qa', sha: shas[2])

      expect(repo.get_shas_with_tag(tag: 'release-to-qa', file: 'file.txt')).to eq [shas[2], shas[0]]
      expect(repo.get_shas_with_tag(tag: 'release-to-qa', file: 'file.txt', order: :ascending)).to eq [shas[0], shas[2]]
      expect(repo.get_shas_with_tag(tag: 'release-to-qa', file: 'other.txt')).to eq [shas[1]]
      expect(repo.get_shas_with_tag(tag: 'blah', file: 'file.txt')).to be_empty
      expect(repo.get_shas_with_tag(tag: 'release-to-qa')).to eq [shas[2], shas[1], shas[0]]
    end
  end

end
