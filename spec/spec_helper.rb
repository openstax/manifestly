$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'manifestly'
require 'byebug'
require 'scenarios'

def absolutize_gem_path(path)
  File.join(File.dirname(__FILE__), '..', path)
end

RSpec.configure do |config|
  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end

    result
  end

  def suppress_output
    original_stderr = $stderr
    original_stdout = $stdout

    begin
      $stderr = File.open(File::NULL, "w")
      $stdout = File.open(File::NULL, "w")

      yield
    ensure
      $stderr = original_stderr
      $stdout = original_stdout
    end
  end

  def std_sha(sha)
    sha[0..9]
  end
end

RSpec::Matchers.define :exit_with_message do |expected_message|
  include RSpec::Matchers::Composable

  match do |actual|
    @stderr = capture(:stderr) {
      @stdout = capture(:stdout) {
        begin
          actual.call
          @failure_message = 'Did not raise `SystemExit`'
        rescue SystemExit
        rescue Exception => e
          @failure_message = "Raised an exception other than `SystemExit` (#{e.inspect})"
        end
      }
    }

    # Just choose one
    @actual_message = @stdout.blank? ? @stderr : @stdout

    if expected_message.is_a?(String)
      expect(@actual_message).to eq expected_message
    else
      expect(@actual_message).to match expected_message
    end
  end

  supports_block_expectations

  failure_message do |actual|
    @failure_message || "expected the error message '#{@actual_message}' to match '#{expected_message}'"
  end
end

RSpec::Matchers.define :have_sha_tag do |sha,expected_tag|
  include RSpec::Matchers::Composable

  match do |git|
    sha_tags = git.tags.select{|tag| tag.contents.match("object #{sha}")}
    sha_tags.map(&:name).any?{|tag_value| tag_value.match(expected_tag)}
  end

  failure_message do |git|
    "expected that #{git.dir} would have tag #{expected_tag} on sha #{sha}"
  end

  failure_message_when_negated do |git|
    "expected that #{git.dir} would not have tag #{expected_tag} on sha #{sha}"
  end
end
