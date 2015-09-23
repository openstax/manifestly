require 'fileutils'

class Manifestly::Repository

  class CommitNotPresent < StandardError; end
  class ManifestUnchanged < StandardError; end

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

  def get_commit_lines(sha)
    diff_lines = find_commit(sha).diff_parent.to_s.split("\n")
    # ditch info lines and '-' lines
    relevant_lines = diff_lines[5..-1].grep(/^[\+ ]/)
    # remove the first character from each line ('+', ' ')
    relevant_lines.collect{|line| line[1..-1]}
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
