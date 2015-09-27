require 'fileutils'

module Manifestly
  class Repository

    class CommitNotPresent < StandardError; end
    class ManifestUnchanged < StandardError; end
    class CommitContentError < StandardError; end
    class NoCommitsError < StandardError; end

    # Returns an object if can load a git repository at the specified path,
    # otherwise nil
    def self.load(path)
      repository = new(path)
      repository.is_git_repository? ? repository : nil
    end

    # Loads a gem-cached copy of the specified repository, cloning it if
    # necessary.
    def self.load_cached(github_name, options)
      options[:update] ||= false

      raise(IllegalArgument, "Repository name is blank.") if github_name.blank?

      path = "./.manifestly/.manifest_repositories/#{github_name}"
      FileUtils.mkdir_p(path)

      repository = load(path)

      if repository.nil?
        url = "git@github.com:#{github_name}.git"
        Git.clone(url, path)
        repository = new(path)
      end

      repository.make_like_just_cloned! if options[:update]
      repository
    end

    def is_git_repository?
      begin
        git
      rescue ArgumentError
        false
      end
    end

    def git
      Git.open(@path)
    end

    def make_like_just_cloned!
      git.branch('master').checkout
      git.fetch
      git.reset_hard('origin/master')
    end

    def push_file!(local_file_path, repository_file_path, message)
      full_repository_file_path = File.join(@path, repository_file_path)
      FileUtils.cp(local_file_path, full_repository_file_path)
      git.add(repository_file_path)
      raise ManifestUnchanged if git.status.changed.empty?
      git.commit(message)
      git.push
    end

    def commits
      begin
        log = git.log(1000000) # don't limit
        log = log.grep("Merge pull request") if @prs_only
        log.tap(&:first) # tap to force otherwise lazy checks
      rescue Git::GitExecuteError => e
        raise NoCommitsError
      end
    end

    # returns the commit matching the provided sha or raises
    def find_commit(sha)
      begin
        git.gcommit(sha).tap(&:sha)
      rescue Git::GitExecuteError => e
        raise CommitNotPresent, "SHA not found: #{sha}"
      end
    end

    def get_commit_content(sha)
      diff_string = find_commit("#{sha}^").diff(sha).to_s
      sha_diff = Diff.new(diff_string)

      raise(CommitContentError, "No content to retrieve for SHA #{sha}!") if sha_diff.num_files == 0
      raise(CommitContentError, "More than one file in the commit for SHA #{sha}!") if sha_diff.num_files > 1

      sha_diff[0].to_content
    end

    def file_commits(file)
      commits = git.log
      commits = commits.select do |commit|
        diff = Diff.new(commit.diff_parent.to_s)
        diff.has_surviving_file?(file)
      end
    end

    def checkout_commit(sha)
      git.checkout(sha)
    end

    def current_branch_name
      git.lib.branch_current
    end

    def toggle_prs_only
      @prs_only = !@prs_only
    end

    def origin
      @origin ||= git.remotes.select{|remote| remote.name == 'origin'}.first
    end

    def github_name
      return nil if origin.nil?
      origin.url[/github.com.(.*).git/,1]
    end

    def working_dir
      git.dir
    end

    def display_name
      github_name || working_dir
    end

    protected

    def initialize(path)
      @path = path
      @commit_page = 0
      @prs_only = false
    end

  end
end
