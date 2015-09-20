require "thor"
require 'rainbow'
require 'command_line_reporter'
require 'git'
require 'securerandom'

# TODO make ruby 1.9 compatible

module Manifestly
  class CLI < Thor
    package_name "manifestly"

    include CommandLineReporter
    include Manifestly::Ui

    def self.search_paths_option
      method_option :search_paths,
                    :desc => "A list of paths where git repositories can be found",
                    :type => :array,
                    :required => false,
                    :default => '.'
    end

    desc "create", "Create a new manifest"
    search_paths_option
    method_option :based_on,
                  :desc => "A manifest file to use as a starting point",
                  :type => :string,
                  :required => false
    def create
      manifest = if options[:based_on]
        Manifest.read(options[:based_on], available_repositories)
      else
        Manifest.new
      end

      present_manifest_menu(manifest)
    end

    desc "apply", "Sets the manifest's repository's current states to the commits listed in the manifest"
    search_paths_option
    method_option :file,
                  :desc => "The manifest file to apply",
                  :type => :string,
                  :required => true
    def apply
      manifest = Manifest.read(options[:file], available_repositories)
      manifest.items.each(&:checkout_commit!)
    end

    desc "push", "Pushes a local manifest file to a manifest repository"
    method_option :local,
                  :desc => 'The local manifest file to push',
                  :type => :string,
                  :required => true
    method_option :mfrepo,
                  :desc => "The repository to push to (full URL or 'organization/reponame')",
                  :type => :string,
                  :required => true
    method_option :remote,  # mfrepo_file?
                  :desc => "The name of the remote file",
                  :type => :string,
                  :required => true
    method_option :message,
                  :desc => "A commit message describing this manifest",
                  :type => :string,
                  :required => false
    def push
      say("Not yet implemented.")
      return
      # manifest = Manifest.read(options[:file], available_repositories)
      manifest_repository = ManifestRepository.get(options[:mfrepo])
      # update the mfrepo (fetch) if not done by ManifestRepository
      # write the manifest file to the targeted file
    end

    desc "pull", "Downloads a manifest file from a manifest repository"
    method_option :sha,
                  :desc => "The commit SHA of the manifest on the remote repository",
                  :type => :string,
                  :required => true
    method_option :mfrepo,
                  :desc => "The manifest repository to pull from (full URL or 'organization/reponame')",
                  :type => :string,
                  :required => true
    method_option :save_as,
                  :desc => "The name to use for the downloaded file (defaults to '<SHA>.manifest')",
                  :type => :string,
                  :required => false
    def pull
      say("Not yet implemented.")
    end

    desc "list", "Lists manifests from a manifest repository"
    method_option :mfrepo,
                  :desc => "The manifest repository to read from (full URL or 'organization/reponame')",
                  :type => :string,
                  :required => true
    method_option :remote,
                  :desc => "The name of the manifest to read from",
                  :type => :string,
                  :required => true
    def list
      say("Not yet implemented.")
    end

    protected

    def present_manifest_menu(manifest)
      while true
        print_manifest(manifest)

        action, args = ask_and_split(
          '(a)dd or (r)emove repository; (c)hoose commit; (w)rite manifest; (q)uit:'
        ) || next

        case action
        when 'a'
          add_repositories(manifest)
        when 'r'
          indices = convert_args_to_indices(args) || next
          manifest.remove_repositories_by_index(indices)
        when 'c'
          indices = convert_args_to_indices(args, true) || next
          present_commit_menu(manifest[indices.first])
        when 'w'
          default_filename = Time.now.strftime("%Y%m%d-%H%M%S") + "-#{::SecureRandom.hex(2)}.manifest"
          filename = ask("Enter desired manifest filename (ENTER for '#{default_filename}'):")
          filename = default_filename if filename.blank?

          manifest.write(filename)
          break
        when 'q'
          break if yes?('Are you sure you want to quit? (y or yes):')
        end
      end
    end

    def present_commit_menu(manifest_item)
      while true
        print_commit_shas(manifest_item)

        action, args = ask_and_split(
          '(n)ext or (p)revious page; (c)hoose index; (m)anual SHA entry; (t)oggle PRs only; (r)eturn:'
        ) || next

        case action
        when 'n'
          manifest_item.repository.next_page_of_commits
        when 'p'
          manifest_item.repository.prev_page_of_commits
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
        when 'r'
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

    def add_repositories(manifest)
      puts "\n"
      selected_repositories = select(
        repository_choices,
        hide_shortcuts: true,
        choice_name: "repository",
        question: "\nChoose which repositories you want in the manifest (e.g. '0 2 5'):"
      )

      selected_repositories.each do |repository|
        manifest.add_repository(repository)
      end
    end

    def print_manifest(manifest)
      puts "\n"
      puts "Current Manifest:\n"
      puts "\n"
      table :border => false do
        row :header => true do
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

    def print_commit_shas(manifest_item)
      puts "\n"
      puts "Commit SHAs for #{manifest_item.repository_name}:\n"
      puts "\n"
      table :border => true do
        row :header => true do
          column "#", width: 4
          column "SHA", width: 10
          column "Message", width: 54
          column "Date", width: 25
        end

        manifest_item.repository.commits.each_with_index do |commit, index|
          row do
            column "#{index}", align: 'right'
            column "#{commit.sha[0..9]}"
            column "#{summarize_commit_message(commit)}"
            column "#{commit.date}"
          end
        end
      end
      puts "\n"
    end

    def summarize_commit_message(commit)
      commit.message
        .gsub(/Merge pull request (#\w+)( from [\w-]+\/[\w-]+)/, 'PR \1')
        .gsub("\n",' ')
        .gsub(/\s+/, ' ')[0..79]
    end

    def repository_choices
      available_repositories.collect{|repo| {display: repo.github_name || repo.working_dir, value: repo}}
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

  end
end
