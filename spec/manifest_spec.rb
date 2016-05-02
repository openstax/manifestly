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
end
