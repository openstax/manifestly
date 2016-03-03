require 'spec_helper'

describe Scenarios do

  it 'subs fake_commits' do
    expect(Scenarios.sub_fake_commit("fake_commit | repo:blah | comment: How are you")).to match /\Acd blah\n.*\n.*\n.*How are you/
  end

  it 'subs aliases' do
    input = "line1\nfake_commit|repo:blah|comment:hi|\nline 3"
    expect(Scenarios.sub_aliases(input)).to match /line1\ncd blah\n.*\n.*\n.*'hi'\ncd ..\nline 3/
  end

end
