require "thor"
require 'rainbow'
require 'command_line_reporter'
require 'git'
require 'securerandom'
require 'ruby-progressbar'

module Manifestly
  class CLI < Thor
    package_name "manifestly"

    include CommandLineReporter
    include Manifestly::Ui

    #
    # Common command line options
    #

    def self.search_paths_option
      method_option :search_paths,
                    desc: "A list of paths where git repositories can be found",
                    type: :array,
                    required: false,
                    banner: '',
                    default: '.'
    end

    def self.repo_option
      method_option :repo,
                    desc: "The github manifest repository to use, given as 'organization/reponame'",
                    type: :string,
                    banner: '',
                    required: true
    end

    def self.repo_file_option(description=nil)
      description ||= "The name of the repository file, with path if applicable"
      method_option :repo_file,
                    desc: description,
                    type: :string,
                    banner: '',
                    required: true
    end

    def self.file_option(description_action=nil)
      description = "The local manifest file"
      description += " to #{description_action}" if description_action

      method_option :file,
                    desc: description,
                    type: :string,
                    banner: '',
                    required: true
    end

    #
    # Command-line actions
    #

    desc "create", "Create a new manifest"
    search_paths_option
    method_option :based_on,
                  desc: "A manifest file to use as a starting point",
                  type: :string,
                  banner: '',
                  required: false
    long_desc <<-DESC
      Interactively create a manifest file, either from scratch or using
      an exisitng manifest as a starting point.

      When run, the current manifest will be shown and you will have the
      following options:

      (a)dd repository - entering 'a' will show you a list of repositories
        that can be added.  Select multiple by index on this chooser screen.

      (r)emove repository - entering 'r' followed by a manifest index will
        remove that repository from the manifest, e.g. 'r 3'

      (f)etch - entering 'f' will fetch the contents of the manifest repos.
        The selectable commits will only include those that have been fetched.

      (c)hoose commit - entering 'c' followed by a manifest index will show
        you a screen where you can choose the manifest commit for that repo.
        (see details below)

      (w)rite manifest - entering 'w' will prompt you for a name to use when
        writing out the manifest to disk.

      (q)uit - entering 'q' exits with a "are you sure?" prompt. 'q!' exits
        immediately.

      When choosing commits,

      (n)ext page / (p)revious page - entering 'n' or 'p' will page through commits.

      (c)hoose index - entering 'c' followed by a table index chooses that commit,
        e.g. 'c 12'

      (m)anual SHA entry - entering 'm' followed by a SHA fragment selects that
        commit, e.g. 'm 8623e'

      (t)oggle PRs only - entering 't' toggles filtering by PR commits only

      (r)eturn - entering 'r' returns to the previous menu

      Examples:

      $ manifestly create\x5
      Create manifest from scratch with the default search path

      $ manifestly create --search_paths=..\x5
      Create manifest looking for repositories one dir up

      $ manifestly create --based_on=~my.manifest --search_paths=~jim/repos\x5
      Create manifest starting from an existing one
    DESC
    def create
      manifest = if options[:based_on]
        read_manifest(options[:based_on]) || return
      else
        Manifest.new
      end

      present_create_menu(manifest)
    end

    desc "apply", "Sets the manifest's repository's current states to the commits listed in the manifest"
    search_paths_option
    file_option("apply")
    long_desc <<-DESC
      Check to make sure the repositories you are deploying from have their state committed.
    DESC
    def apply
      begin
        manifest = read_manifest(options[:file]) || return
      rescue Manifestly::ManifestItem::MultipleSameNameRepositories => e
        say "Multiple repositories have the same name (#{e.message}) so we " +
            "can't apply the manifest. Try limiting the search_paths or " +
            "separate the duplicates."
        return
      end
      manifest.items.each(&:checkout_commit!)
    end

    desc "upload", "Upload a local manifest file to a manifest repository"
    file_option("upload")
    repo_option
    repo_file_option("The name of the manifest to upload to in the repository, with path if applicable")
    method_option :message,
                  desc: "A message to permanently record with this manifest",
                  type: :string,
                  banner: '',
                  required: true
    long_desc <<-DESC
      Upload a manifest when you want to share it with others or persist it
      permanently.  Since manifests are stored remotely as versions of a file
      in git, it cannot be changed once uploaded.
    DESC
    def upload
      repository = Repository.load_cached(options[:repo], update: true)

      begin
        repository.push_file!(options[:file], options[:repo_file], options[:message])
      rescue Manifestly::Repository::ManifestUnchanged => e
        say "The manifest you requested to push is already the latest and so could not be pushed."
      end
    end

    desc "download", "Downloads a manifest file from a manifest repository"
    method_option :sha,
                  desc: "The commit SHA of the manifest on the remote repository",
                  type: :string,
                  banner: '',
                  required: true
    repo_option
    method_option :save_as,
                  desc: "The name to use for the downloaded file (defaults to '<SHA>.manifest')",
                  type: :string,
                  banner: '',
                  required: false
    long_desc <<-DESC
      You must have a copy of a manifest locally to `apply` it to your local
      repositories.  A local copy is also useful when creating a new manifest
      based on an existing one.
    DESC
    def download
      repository = Repository.load_cached(options[:repo], update: true)

      commit_content = begin
        repository.get_commit_content(options[:sha])
      rescue Manifestly::Repository::CommitNotPresent
        say('That SHA is invalid')
        return
      end

      save_as = options[:save_as]

      if save_as.nil?
        # Get the whole SHA so filenames are consistent
        sha = repository.find_commit(options[:sha]).sha
        save_as = "#{sha[0..9]}.manifest"
      end

      File.open(save_as, 'w') { |file| file.write(commit_content) }
      say "Downloaded #{save_as}.  #{commit_content.split("\n").count} line(s)."
    end

    desc "list", "Lists variants of one manifest from a manifest repository"
    repo_option
    repo_file_option("list variants of")
    long_desc <<-DESC
      Right now you can't do much other than see the versions of a manifest.
      (Versions of a manifest are just revisions of the file in a git history,
      which is why the versions are identified by SHA hashes.).  Later we can
      add the ability to download, apply, or create directly from the listing.
    DESC
    def list
      repository = Repository.load_cached(options[:repo], update: true)
      commits = repository.file_commits(options[:repo_file])
      present_list_menu(commits, show_author: true)
    end

    protected

    def present_create_menu(manifest)
      while true
        print_manifest(manifest)

        action, args = ask_and_split(
          '(a)dd or (r)emove repository; (f)etch; (c)hoose commit; (w)rite manifest; (q)uit:'
        ) || next

        case action
        when 'a'
          add_repositories(manifest)
        when 'r'
          indices = convert_args_to_indices(args) || next
          manifest.remove_repositories_by_index(indices)
        when 'f'
          progress = ProgressBar.create(title: "Fetching", total: manifest.items.count)
          manifest.items.each do |item|
            item.fetch
            progress.increment
          end
        when 'c'
          indices = convert_args_to_indices(args, true) || next
          present_commit_menu(manifest[indices.first])
        when 'w'
          default_filename = Time.now.strftime("%Y%m%d-%H%M%S") + "-#{::SecureRandom.hex(2)}.manifest"
          filename = ask("Enter desired manifest filename (ENTER for '#{default_filename}'):")
          filename = default_filename if filename.blank?

          manifest.write(filename)
          break
        when 'q!'
          break
        when 'q'
          break if yes?('Are you sure you want to quit? (y or yes):')
        end
      end
    end

    def present_commit_menu(manifest_item, options={})
      page = 0

      while true
        options[:page] = page
        print_commits(manifest_item.repository.commits, options)

        action, args = ask_and_split(
          '(n)ext or (p)revious page; (c)hoose index; (m)anual SHA entry; (t)oggle PRs only; (r)eturn:'
        ) || next

        case action
        when 'n'
          page += 1
        when 'p'
          page -= 1
        when 'c'
          indices = convert_args_to_indices(args, true) || next
          manifest_item.set_commit_by_index(indices.first)
          break
        when 'm'
          sha = args.first
          begin
            manifest_item.set_commit_by_sha(sha)
            break
          rescue CommitNotPresent
            say('That SHA is invalid')
            next
          end
        when 't'
          manifest_item.repository.toggle_prs_only
          page = 0
        when 'r'
          break
        end
      end
    end

    def present_list_menu(commits, options={})
      page = 0

      while true
        options[:page] = page
        print_commits(commits, options)

        action, args = ask_and_split(
          '(n)ext or (p)revious page; (q)uit:'
        ) || next

        case action
        when 'n'
          page += 1
        when 'p'
          page -= 1
        when 'q'
          break
        end
      end
    end

    def ask_and_split(message)
      answer = ask(message).downcase.split

      if answer.empty?
        say('No response provided, please try again.')
        return false
      end

      [answer.shift, answer]
    end

    def convert_args_to_indices(args, select_one=false)
      if args.empty?
        say('You must specify index(es) of manifest items after the action, e.g. "r 2 7".')
        false
      elsif select_one && args.size > 1
        say('You can only specify one manifest index for this action.')
        false
      elsif args.any? {|si| !si.is_i?}
        say('All specified indices must be integers.')
        false
      else
        args.collect{|index| index.to_i}
      end
    end

    def read_manifest(file)
      begin
        Manifest.read(file, available_repositories)
      rescue Manifestly::ManifestItem::RepositoryNotFound
        say "Couldn't find all the repositories listed in #{file}.  " +
            "Might need to specify --search_paths."
        nil
      end
    end

    def add_repositories(manifest)
      puts "\n"

      selected_repositories = select(
        repository_choices(manifest),
        hide_shortcuts: true,
        choice_name: "repository",
        question: "\nChoose which repositories you want in the manifest (e.g. '0 2 5') or (r)eturn:",
        no_selection: 'r'
      )

      return if selected_repositories.nil?

      selected_repositories.each do |repository|
        begin
          manifest.add_repository(repository)
        rescue Manifestly::Repository::NoCommitsError => e
          say "Cannot add #{repository.display_name} because it doesn't have any commits."
        end
      end
    end

    def print_manifest(manifest)
      puts "\n"
      puts "Current Manifest:\n"
      puts "\n"
      table border: false do
        row header: true do
          column "#", width: 4
          column "Repository", width: 36
          column "Branch", width: 30
          column "SHA", width: 10
        end

        if manifest.empty?
          row do
            column ""
            column "----- EMPTY -----"
          end
        else
          manifest.items.each_with_index do |item, index|
            row do
              column "(#{index})", align: 'right', width: 4
              column "#{item.repository_name}", width: 40
              column "#{item.repository.current_branch_name}"
              column "#{item.commit.sha[0..9]}", width: 10
            end
          end
        end
      end
      puts "\n"
    end

    def print_commits(commits, options={})
      column_widths = {
        number: 4,
        sha: 10,
        message: 54,
        author: options[:show_author] ? 14 : 0,
        date: 25
      }

      num_columns = column_widths.values.count{|v| v != 0}
      total_column_widths = column_widths.values.inject{|sum,x| sum + x }
      total_table_width =
        total_column_widths +
        num_columns + 1     +    # column separators
        num_columns * 2          # padding

      width_overage = total_table_width - terminal_width

      if width_overage > 0
        column_widths[:message] -= width_overage
      end

      page = options[:page] || 0
      per_page = options[:per_page] || 15

      last_page = commits.size / per_page
      last_page -= 1 if commits.size % per_page == 0 # account for full pages

      page = 0 if page < 0
      page = last_page if page > last_page

      first_commit = page*per_page
      last_commit  = [page*per_page+per_page-1, commits.size-1].min

      page_commits = commits[first_commit..last_commit]

      table border: true do
        row header: true do
          column "#", width: column_widths[:number]
          column "SHA", width: column_widths[:sha]
          column "Message", width: column_widths[:message]
          column "Author", width: column_widths[:author] if options[:show_author]
          column "Date", width: column_widths[:date]
        end

        page_commits.each_with_index do |commit, index|
          row do
            column "#{index}", align: 'right'
            column "#{commit.sha[0..9]}"
            column "#{summarize_commit_message(commit)}"
            column "#{commit.author.name[0..13]}" if options[:show_author]
            column "#{commit.date}"
          end
        end
      end
    end

    def summarize_commit_message(commit)
      commit.message
        .gsub(/Merge pull request (#\w+)( from [\w-]+\/[\w-]+)/, 'PR \1')
        .gsub("\n",' ')
        .gsub(/\s+/, ' ')[0..79]
    end

    def repository_choices(except_in_manifest=nil)
      choices = available_repositories.collect{|repo| {display: repo.display_name, value: repo}}
      except_in_manifest.nil? ?
        choices :
        choices.reject{|choice| except_in_manifest.includes?(choice[:value])}
    end

    def available_repositories
      @available_repositories ||= (repository_search_paths.flat_map do |path|
        directories_under(path).collect{|dir| Manifestly::Repository.load(dir)}
      end).compact
    end

    def directories_under(path)
      entries = Dir.entries(path)
      entries.reject!{ |dir| dir =='.' || dir == '..' }

      full_entry_paths = entries.collect{|entry| File.join(path, entry)}
      full_entry_paths.reject{ |path| !File.directory?(path) }
    end

    def repository_search_paths
      [options[:search_paths]].flatten
    end

    def terminal_height
      # This code was derived from Thor and from Rake, the latter of which is
      # available under MIT-LICENSE Copyright 2003, 2004 Jim Weirich
      if ENV["THOR_ROWS"]
        result = ENV["THOR_ROWS"].to_i
      else
        result = unix? ? dynamic_width : 40
      end
      result < 10 ? 40 : result
    rescue
      40
    end

    def dynamic_height
      %x{stty size 2>/dev/null}.split[0].to_i
    end

  end
end
