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

    def checkout_commit!(fetch_if_unfound=false)
      @repository.checkout_commit(@commit.sha, fetch_if_unfound)
    end

    def commit_tags
      @repository.git.tags.select do |tag|
        # Gotta do some digging to get tagged sha out of annotated tags
        tagged_sha = tag.annotated? ?
                     tag.contents_array[0].split(" ").last == commit :
                     tag.sha

        tagged_sha == commit.sha
      end.map(&:name)
    end

    def to_file_string
      dir = @repository.deepest_working_dir
      repo = @repository.github_name_or_path
      tags = commit_tags

      "[#{dir}]#{repo.nil? ? '' : ' ' + repo}@#{commit.sha[0..9]}#{' # ' + tags.join(",") if tags.any?}"
    end

    def self.from_file_string(string, repositories)
      repo_name, dir, sha = parse_file_string(string)

      matching_repositories = repositories.select do |repo|
        # directory name will be the most unique way to match and should always be available
        # wheres repo_name won't always be
        repo.deepest_working_dir == dir
      end

      # TODO test these two exceptions!
      if matching_repositories.size > 1
        raise(MultipleSameNameRepositories, "Dir: [#{dir}], Repo: [#{repo_name}]")
      end

      if matching_repositories.empty?
        raise(RepositoryNotFound, "Dir: [#{dir}], Repo: [#{repo_name}]")
      end

      repository = matching_repositories.first

      item = ManifestItem.new(repository)
      item.set_commit_by_sha(sha)
      item
    end

    def self.parse_file_string(string)
      sha_re = "([a-fA-F0-9]+)"
      repo_re = '([\w-]+\/[\w-]+)'
      old_dir_re_1 = '\((.*)\)'
      old_dir_re_2 = '(.*)'
      new_dir_re = '\[(.*)\]'

      # New style: `[dir] org/repo@sha`
      if string =~ /#{new_dir_re}\W*#{repo_re}\W*@\W*#{sha_re}/
        dir = $1.strip
        repo_name = $2.strip
        sha = $3.strip
      # New style where there is no GH repo: `[dir]@sha`
      elsif string =~ /#{new_dir_re}\W*@\W*#{sha_re}/
        dir = $1.strip
        sha = $2.strip
      # Old style with dir shown: `org/repo (dir) @ sha`
      elsif string =~ /#{repo_re}\W*#{old_dir_re_1}\W*@\W*#{sha_re}/
        repo_name = $1.strip
        dir = $2.strip
        sha = $3.strip
      # Old style with implicit dir: `org/repo @ sha`
      elsif string =~ /#{repo_re}\W*@\W*#{sha_re}/
        repo_name = $1.strip
        sha = $2.strip
        dir = repo_name.split('/').last
      # Old style with no repo: `dir @ sha`
      elsif string =~ /#{old_dir_re_2}\W*@\W*#{sha_re}/
        dir = $1.strip
        sha = $2.strip
      else
        raise(InvalidManifestItem, string)
      end

      [repo_name, dir, sha]
    end

    attr_accessor :commit
    attr_reader :repository

  end
end
