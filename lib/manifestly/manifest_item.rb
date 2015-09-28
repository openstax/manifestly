module Manifestly
  class ManifestItem

    class InvalidManifestItem < StandardError; end
    class RepositoryNotFound < StandardError; end
    class MultipleSameNameRepositories < StandardError; end

    def initialize(repository)
      @repository = repository
      @commit = repository.current_commit
    end

    def repository_name
      @repository.display_name
    end

    def set_commit_by_index(index)
      @commit = @repository.commits[index]
    end

    def set_commit_by_sha(sha)
      @commit = @repository.find_commit(sha)
    end

    def fetch
      @repository.fetch
    end

    def checkout_commit!
      @repository.checkout_commit(@commit.sha)
    end

    def to_file_string
      "#{repository_name} @ #{commit.sha}"
    end

    def self.from_file_string(string, repositories)
      repo_name, sha = string.split('@').collect(&:strip)
      raise(InvalidManifestItem, string) if repo_name.blank? || sha.blank?

      matching_repositories = repositories.select{|repo| repo.github_name == repo_name}
      raise(MultipleSameNameRepositories, repo_name) if matching_repositories.size > 1
      raise(RepositoryNotFound, repo_name) if matching_repositories.empty?
      repository = matching_repositories.first

      item = ManifestItem.new(repository)
      item.set_commit_by_sha(sha)
      item
    end

    attr_accessor :commit
    attr_reader :repository

  end
end
