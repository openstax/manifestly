$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'manifestly'
require 'byebug'

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
end
