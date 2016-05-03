require 'fileutils'
require 'ostruct'

module Manifestly
  class Repository

    class CommitNotPresent < StandardError
      attr_reader :sha, :repository
      def initialize(sha, repository)
        @sha = sha
        @repository = repository
        super("SHA '#{sha}' not found in repository '#{repository.github_name_or_path}'")
      end
    end

    class ManifestUnchanged < StandardError; end
    class CommitContentError < StandardError; end
    class NoCommitsError < StandardError; end
    # class TagNotFound < StandardError; end
    class TagShaNotFound < StandardError; end
    class ShaAlreadyTagged < StandardError; end

    # Returns an object if can load a git repository at the specified path,
    # otherwise nil
    def self.load(path)
      repository = new(path)
      repository.is_git_repository? ? repository : nil
    end

    # Loads a gem-cached copy of the specified repository, cloning it if
    # necessary.
    def self.load_cached(github_name_or_path, options)
      options[:update] ||= false

      raise(IllegalArgument, "Repository name is blank.") if github_name_or_path.blank?

      cached_path = "#{Manifestly.configuration.cached_repos_root_dir}/.manifestly/.manifest_repositories/#{github_name_or_path}"
      FileUtils.mkdir_p(cached_path)

      repository = load(cached_path)

      if repository.nil?
        remote_location = is_github_name?(github_name_or_path) ?
                            "git@github.com:#{github_name_or_path}.git" :
                            github_name_or_path
        Git.clone(remote_location, cached_path)
        repository = new(cached_path)
      end

      repository.make_like_just_cloned! if options[:update]
      repository
    end

    def self.is_github_name?(value)
      value.match(/\A[^\/]+\/[^\/]+\z/)
    end

    def is_git_repository?
      begin
        git
      rescue ArgumentError
        false
      end
    end

    def has_commits?
      begin
        git && commits
      rescue NoCommitsError
        false
      end
    end

    def fetch
      git.fetch
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
      raise ManifestUnchanged if git.status.changed.empty? && git.status.added.empty?
      git.commit(message)
      git.push
    end

    def commits(options={})
      begin
        log = git.log(1000000).object('master') # don't limit
        log = log.between(options[:between][0], options[:between][1]) if options[:between]
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
        raise CommitNotPresent.new(sha, self)
      end
    end

    def get_commit_content(sha)
      get_commit_file(sha).to_content
    end

    def get_commit_filename(sha)
      get_commit_file(sha).to_name
    end

    def get_commit_file(sha)
      diff_string = begin
        git.show(sha)
      rescue Git::GitExecuteError => e
        if is_commit_not_found_exception?(e)
          raise CommitNotPresent.new(sha, self)
        else
          raise
        end
      end

      sha_diff = Diff.new(diff_string)

      raise(CommitContentError, "No content to retrieve for SHA #{sha}!") if sha_diff.num_files == 0
      raise(CommitContentError, "More than one file in the commit for SHA #{sha}!") if sha_diff.num_files > 1

      sha_diff[0]
    end

    def file_commits(file)
      commits = git.log
      commits = commits.select do |commit|
        diff = Diff.new(commit.diff_parent.to_s)
        diff.has_file?(file)
      end
    end

    def checkout_commit(sha, fetch_if_unfound=false)
      begin
        git.checkout(sha)
      rescue Git::GitExecuteError => e
        if is_commit_not_found_exception?(e)
          if fetch_if_unfound
            git.fetch
            checkout_commit(sha, false)
          else
            raise CommitNotPresent.new(sha, self)
          end
        else
          raise
        end
      end
    end

    def is_commit_not_found_exception?(e)
      e.message.include?("fatal: reference is not a tree") ||
      e.message.include?("fatal: ambiguous argument")
    end

    def current_branch_name
      git.lib.branch_current
    end

    def current_commit
      sha = git.show.split("\n")[0].split(" ")[1]
      find_commit(sha)
    end

    def tag_scoped_to_file(options={})
      raise(IllegalArgument, "Tag names cannot contain forward slashes") if options[:tag].include?("/")

      options[:push] ||= false
      options[:message] ||= "no message"

      existing_shas = get_shas_with_tag(tag: options[:tag])
      raise(ShaAlreadyTagged) if existing_shas.include?(options[:sha])

      filename = get_commit_filename(options[:sha])
      tag = "#{Time.now.utc.strftime("%Y%m%d-%H%M%S.%6N")}/#{::SecureRandom.hex(2)}/#{filename}/#{options[:tag]}"
      git.add_tag(tag, options[:sha], {annotate: true, message: options[:message], f: true})
      git.push('origin', "refs/tags/#{tag}", f: true) if options[:push]
    end

    def get_shas_with_tag(options={})
      options[:file] ||= ".*"
      options[:order] ||= :descending

      pattern = /.*\/#{options[:file]}\/#{options[:tag]}/

      tag_objects = git.tags.select{|tag| tag.name.match(pattern)}
                            .sort_by(&:name)

      tag_objects.reverse! if options[:order] == :descending

      tag_objects.collect do |tag_object|
        matched_sha = tag_object.contents.match(/[a-f0-9]{40}/)
        raise(TagShaNotFound, "Could not retrieve SHA for tag '#{full_tag}'") if matched_sha.nil?
        matched_sha.to_s
      end
    end

    def toggle_prs_only
      @prs_only = !@prs_only
    end

    def origin
      @origin ||= git.remotes.select{|remote| remote.name == 'origin'}.first
    end

    def github_name_or_path
      # Extract 'org/reponame' out of remote url for both HTTP and SSH clones
      return nil if origin.nil?
      origin.url[/github.com.(.*?)(.git)?$/,1]
    end

    def working_dir
      git.dir
    end

    def display_name
      if github_name_or_path
        repo_name = github_name_or_path.split('/').last
        dir_name = working_dir.to_s.split(File::SEPARATOR).last
        if repo_name == dir_name
          github_name_or_path
        else
          github_name_or_path + " (#{dir_name})"
        end
      else
        working_dir.to_s.split('/').last
      end
    end

    protected

    def initialize(path)
      @path = path
      @commit_page = 0
      @prs_only = false
    end

  end
end
