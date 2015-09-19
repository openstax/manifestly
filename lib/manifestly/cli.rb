require "thor"
require 'rainbow'
require 'command_line_reporter'
require 'byebug'
require 'git'
require 'securerandom'

# TODO make ruby 1.9 compatible

module Manifestly
  class CLI < Thor

    include CommandLineReporter
    include Manifestly::Ui

    def self.common_method_options
      method_option :search_paths,
                    :type => :array,
                    :required => false,
                    :default => '.'
    end

    desc "create", "Create a new repository"
    common_method_options
    def create
      # TODO allow starting from an existing manifest, either by filename or SHA

      manifest = Manifest.new
      present_manifest_menu(manifest)
    end

    protected

    def present_manifest_menu(manifest)
      while true
        print_manifest(manifest)

        action, options = ask_and_split(
          '(a)dd or (r)emove repository; (c)hoose commit; (w)rite manifest; (q)uit:'
        ) || next

        case action
        when 'a'
          add_repositories(manifest)
        when 'r'
          indices = convert_options_to_indices(options) || next
          manifest.remove_repositories_by_index(indices)
        when 'c'
          indices = convert_options_to_indices(options, true) || next
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

        action, options = ask_and_split(
          '(n)ext or (p)revious page; (c)hoose index; (m)anual SHA entry; (t)oggle PRs only; (r)eturn:'
        ) || next

        case action
        when 'n'
          manifest_item.repository.next_page_of_commits
        when 'p'
          manifest_item.repository.prev_page_of_commits
        when 'c'
          indices = convert_options_to_indices(options, true) || next
          manifest_item.set_commit_by_index(indices.first)
          break
        when 'm'
          sha = options.first
          begin
            manifest_item.set_commit_by_sha(sha)
            break
          rescue Git::GitExecuteError
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

    def convert_options_to_indices(options, select_one=false)
      if options.empty?
        say('You must specify index(es) of manifest items after the action, e.g. "r 2 7".')
        false
      elsif select_one && options.size > 1
        say('You can only specify one manifest index for this action.')
        false
      elsif options.any? {|si| !si.is_i?}
        say('All specified indices must be integers.')
        false
      else
        options.collect{|index| index.to_i}
      end
    end

    def add_repositories(manifest)
      selected_repositories = select(
        repository_choices,
        hide_shortcuts: true,
        question: "Choose which repositories you want in the manifest (e.g. '0 2 5'):"
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
          column "Repository", width: 40
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
          # column "Author", width: 14
          column "Date", width: 25
        end

        manifest_item.repository.commits.each_with_index do |commit, index|
          row do
            column "#{index}", align: 'right'
            column "#{commit.sha[0..9]}"
            column "#{summarize_commit_message(commit)}"
            # column "#{commit.author.name[0..13]}"
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
      repositories.collect{|repo| {display: repo.github_name, value: repo}}
    end

    def repositories
      @repositories ||= (repository_search_paths.flat_map do |path|
        directories_under(path).collect{|dir| Manifestly::Repository.load(dir)}
      end).compact
    end

    def new_manifest_filename
      "test_#{::SecureRandom.hex(3)}.manifest"
    end

    def directories_under(path)
      entries = Dir.entries(path)
      entries.reject!{ |dir| dir =='.' || dir == '..' }

      # entries.reject!{ |dir| dir != 'tutor-server' }

      full_entry_paths = entries.collect{|entry| File.join(path, entry)}
      full_entry_paths.reject{ |path| !File.directory?(path) }
    end

    def repository_search_paths
      [options[:search_paths]].flatten
    end

  end
end
