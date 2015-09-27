module Manifestly
  class ManifestItem

    class InvalidManifestItem < StandardError; end
    class RepositoryNotFound < StandardError; end

    def initialize(repository)
      @repository = repository
      @commit = repository.commits.first
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

    def checkout_commit!
      @repository.checkout_commit(@commit.sha)
    end

    def to_file_string
      "#{repository_name} @ #{commit.sha}"
    end

    def self.from_file_string(string, repositories)
      repo_name, sha = string.split('@').collect(&:strip)
      raise(InvalidManifestItem, string) if repo_name.blank? || sha.blank?

      repository = repositories.select{|repo| repo.github_name == repo_name}.first
      raise(RepositoryNotFound, repo_name) if repository.nil?

      item = ManifestItem.new(repository)
      item.set_commit_by_sha(sha)
      item
    end

    attr_accessor :commit
    attr_reader :repository

  end
end
