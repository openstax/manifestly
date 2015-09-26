module Manifestly
  class Diff

    class File
      def initialize(file_diff_string)
        @lines = file_diff_string.split("\n")

        @from_name = @lines[2][6..-1]
        @to_name   = @lines[3][6..-1]

        content_lines = @lines[5..-1]

        @from_content = content_lines.grep(/^[\- ]/).join("\n")
        @to_content = content_lines.grep(/^[\+ ]/).join("\n")
      end

      attr_reader :from_name, :to_name, :from_content, :to_content
    end

    def initialize(diff_string)
      file_strings = diff_string.split("diff --git ")
      file_strings.reject!(&:blank?)
      @files = file_strings.collect{|file_string| File.new(file_string)}
    end

    attr_reader :files

    def has_file?(filename)
      files.any?{|file| file.to_name == filename}
    end

    def num_files
      files.length
    end
  end
end
