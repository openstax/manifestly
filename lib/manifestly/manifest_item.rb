class Manifestly::ManifestItem

  def initialize(repository)
    @repository = repository
    @commit = repository.commits.first
  end

  def repository_name
    @repository.github_name
  end

  def set_commit_by_index(index)
    @commit = @repository.commits[index]
  end

  def set_commit_by_sha(sha)
    @commit = @repository.find_commit(sha)
  end

  def to_file_string
    "#{repository_name} @ #{commit.sha}"
  end

  attr_accessor :commit
  attr_reader :repository

end
