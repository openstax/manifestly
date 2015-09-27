require 'spec_helper'

describe Manifestly::Diff do

  let!(:new_file_diff) { <<-TEXT
diff --git a/foo b/foo
new file mode 100644
index 0000000..0f7aa75
--- /dev/null
+++ b/foo
@@ -0,0 +1,2 @@
+org/repo1 @ sha1
+org/repo2 @ sha2
TEXT
  }

let!(:deleted_file_diff) { <<-TEXT
diff --git a/foo b/foo
deleted file mode 100644
index 0f7aa75..0000000
--- a/foo
+++ /dev/null
@@ -1,2 +0,0 @@
-org/repo1 @ sha1
-org/repo2 @ sha2
TEXT
}

  it 'can parse new file diff' do
    diff = Manifestly::Diff.new(new_file_diff)

    expect(diff.num_files).to eq 1
    expect(diff.has_surviving_file?('foo')).to be_truthy
    expect(diff[0].from_name).to be_nil
    expect(diff[0].to_name).to eq 'foo'
    expect(diff[0].from_content).to eq ''
    expect(diff[0].to_content).to eq "org/repo1 @ sha1\norg/repo2 @ sha2"
  end

  it 'can parse a deleted file diff' do
    diff = Manifestly::Diff.new(deleted_file_diff)

    expect(diff.num_files).to eq 1
    expect(diff.has_surviving_file?('foo')).to be_falsy
    expect(diff[0].from_name).to eq 'foo'
    expect(diff[0].to_name).to be_nil
    expect(diff[0].from_content).to eq "org/repo1 @ sha1\norg/repo2 @ sha2"
    expect(diff[0].to_content).to eq ''


  end

end
