class Manifestly::Repository

  class CommitNotPresent < StandardError; end

  # Returns an object if can load a git repository at the specified path,
  # otherwise nil
  def self.load(path)
    repository = new(path)
    repository.is_git_repository? ? repository : nil
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

  COMMITS_PER_PAGE = 15

  def commits
    log = git.log(COMMITS_PER_PAGE)
    log = log.grep("Merge pull request") if @prs_only
    log.skip(@commit_page * COMMITS_PER_PAGE)
  end

  def next_page_of_commits
    @commit_page += 1
  end

  def prev_page_of_commits
    @commit_page -= 1
  end

  def reset_page_of_commits
    @commit_page = 0
  end

  # returns the commit matching the provided sha or raises
  def find_commit(sha)
    begin
      git.gcommit(sha).tap(&:sha)
    rescue Git::GitExecuteError => e
      raise CommitNotPresent, "SHA not found: #{sha}"
    end
  end

  def checkout_commit(sha)
    git.checkout(sha)
  end

  def current_branch_name
    git.lib.branch_current
  end

  def toggle_prs_only
    @commit_page = 0
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

  protected

  def initialize(path)
    @path = path
    @commit_page = 0
    @prs_only = false
  end

end
