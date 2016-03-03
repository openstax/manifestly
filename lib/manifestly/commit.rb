module Manifestly
  class Commit

    def initialize(commit)
      @commit = commit
    end

    def is_pr?
      @commit.message.starts_with?("Merge pull request")
    end

    def pr_number
      match = @commit.message.match(/Merge pull request #(\d+)/)
      match.nil? ? nil : match[1]
    end

    def summarized_message
      @commit.message
        .gsub(/Merge pull request (#\w+)( from [\w-]+\/[\w-]+)/, 'PR \1')
        .gsub("\n",' ')
        .gsub(/\s+/, ' ')[0..79]
    end

  end
end
