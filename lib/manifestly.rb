require_relative "manifestly/version"
require_relative 'manifestly/utilities'
require_relative 'manifestly/commit'
require_relative 'manifestly/diff'
require_relative 'manifestly/repository'
require_relative 'manifestly/manifest'
require_relative 'manifestly/manifest_diff'
require_relative 'manifestly/ui'
require_relative 'manifestly/cli'

module Manifestly

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    class Configuration
      attr_accessor :cached_repos_root_dir

      def initialize
        reset!
      end

      def reset!
        @cached_repos_root_dir = '.'
      end
    end
  end

end
