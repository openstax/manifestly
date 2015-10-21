module Manifestly
  class Diff

    class File
      def initialize(file_diff_string)
        @lines = file_diff_string.split("\n")

        if content_lines.empty?
          # if there are no content lines the format of the diff is a little different
          names = @lines[0].split(' b/')
          @from_name = names[0][2..-1] # strip "a/" off
          @to_name = names[1]

          if file_diff_string.match(/deleted file mode/)
            @to_name = nil
          elsif file_diff_string.match(/new file mode/)
            @from_name = nil
          end
        else
          @from_name = filename(true)
          @to_name   = filename(false)

          @from_content = content_lines.grep(/^[\- ]/).collect{|l| l[1..-1]}.join("\n")
          @to_content = content_lines.grep(/^[\+ ]/).collect{|l| l[1..-1]}.join("\n")
        end
      end

      attr_reader :from_name, :to_name, :from_content, :to_content

      protected

      def filename(from)
        regex = from ? /^\-\-\- / : /^\+\+\+ /
        filename = @lines.grep(regex).first[6..-1]
        filename = nil if filename == "ev/null"
        filename
      end

      def content_lines
        return @content_lines if @content_lines

        at_at_line_index = @lines.find_index{|ll| ll[0..2] == "@@ "}
        @content_lines = at_at_line_index.nil? ?
                           [] :
                           @lines[at_at_line_index+1..-1]
      end
    end

    def initialize(diff_string)
      file_strings = diff_string.split("diff --git ")
      file_strings.reject!(&:blank?)
      @files = file_strings.collect{|file_string| File.new(file_string)}
    end

    attr_reader :files

    def has_file?(filename)
      files.any?{|file| file.to_name == filename || file.from_name == filename}
    end

    def num_files
      files.length
    end

    def [](index)
      files[index]
    end

  end
end
