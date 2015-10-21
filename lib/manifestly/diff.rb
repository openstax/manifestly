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
        @content_lines = at_at_line_index.nil? ?
                           [] :
                           @lines[at_at_line_index+1..-1]
    def has_file?(filename)
      files.any?{|file| file.to_name == filename || file.from_name == filename}