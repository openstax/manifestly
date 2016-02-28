module Manifestly
  class ManifestDiff

    class ItemDiff
      def initialize(from_item, to_item)
        @from_item = from_item
        @to_item = to_item

        @markdown = "## #{to_item.repository_name}#{item_source_info}\n\n#{commits_markdown}\n"
      end

      def to_markdown
        @markdown
      end

      def from_sha
        @from_item.commit.sha
      end

      def to_sha
        @to_item.commit.sha
      end

      def item_source_info
        new_item? ?
          " (new manifest entry)" :
          " (#{from_sha[0..9]} to #{to_sha[0..9]})"
      end

      def new_item?
        @from_item.nil?
      end

      def commits_markdown
        if new_item?
          "* This manifest item was not in the prior manifest, so all of its commits are new."
        else
          repository = @from_item.repository
          repository.toggle_prs_only

          is_rollback = false

          commits = repository.commits(between: [from_sha, to_sha])

          if commits.size == 0
            # This might be a rollback, so try them backwards
            commits = repository.commits(between: [to_sha, from_sha])
            is_rollback = commits.size != 0
          end

          if commits.size == 0
            "* There were no pull requests merged in this range of commits."
          else
            entries = commits.collect do |commit|
              wrapper = Commit.new(commit)
              entry = wrapper.summarized_message

              entry = "[#{entry}](https://github.com/#{repository.display_name}/pull/#{wrapper.pr_number})" if wrapper.is_pr?

              "1. #{entry}"
            end.join("\n")

            is_rollback ? "These commits were *rolled back*:\n\n#{entries}" : entries
          end
        end
      end
    end

    def initialize(from_manifest, to_manifest)
      @from_manifest = from_manifest
      @to_manifest = to_manifest

      @item_diffs = @to_manifest.items.collect do |to_item|
        from_item = @from_manifest.items.detect do |from_item|
          from_item.repository_name == to_item.repository_name
        end

        ItemDiff.new(from_item, to_item)
      end
    end

    def to_markdown
      "# Manifest Diff\n\n#{manifest_source_info}\n\n#{@item_diffs.collect(&:to_markdown).join("\n")}"
    end

    def manifest_source_info
      repository = @from_manifest.manifest_repository
      file = @from_manifest.manifest_file
      from_sha = @from_manifest.manifest_sha
      to_sha = @to_manifest.manifest_sha

      if repository && file && from_sha && to_sha
        "Comparing manifest *#{file}* on repository *#{repository.display_name}* from commit #{from_sha[0..9]} to #{to_sha[0..9]}."
      else
        "Manifest source info is *unknown*."
      end
    end

  end
end
