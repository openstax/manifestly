require 'spec_helper'

describe Manifestly::Repository do

  it 'should get github_name for ssh clone repos' do
    origin = instance_double("Git::Remote", url: "git@github.com:organization/reponame.git")
    expect_any_instance_of(Manifestly::Repository).to receive(:origin).and_return(origin, origin)
    expect(Manifestly::Repository.new('').github_name).to eq "organization/reponame"
  end

  it 'should get github_name for http cloned repos' do
    origin = instance_double("Git::Remote", url: "http://github.com/organization/reponame")
    expect_any_instance_of(Manifestly::Repository).to receive(:origin).and_return(origin, origin)
    expect(Manifestly::Repository.new('').github_name).to eq "organization/reponame"
  end

  it 'should get github_name for httpS cloned repos' do
    origin = instance_double("Git::Remote", url: "https://github.com/organization/reponame")
    expect_any_instance_of(Manifestly::Repository).to receive(:origin).and_return(origin, origin)
    expect(Manifestly::Repository.new('').github_name).to eq "organization/reponame"
  end

end
