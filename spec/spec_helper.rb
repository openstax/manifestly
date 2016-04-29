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
