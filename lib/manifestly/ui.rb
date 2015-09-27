module Manifestly
  module Ui

    def Ui.included(base)

      def select(choices, options={})

        options[:hide_choices] ||= false
        options[:hide_shortcuts] ||= false
        options[:select_one] ||= false
        options[:choice_name] ||= 'item'
        options[:inputs] ||= []
        options[:question] ||= "Please choose an item:" # make this dependent on choice_name and select_one
        options[:hide_all_choice] ||= false

        if !options[:hide_all_choice]
          choices.push(display: 'All', shortcut: 'all', value: choices.collect{|c| c[:value]})
        end

        selections = []

        if !options[:inputs].empty?
          selections = (choices.select do |choice|
            options[:inputs].any? do |input|
              input.downcase.starts_with?(choice[:shortcut].downcase)
            end
          end).collect{|choice| choice[:value]}

          say Rainbow("The input '#{options[:inputs].join(' ')}' did not match any choices.").red if selections.empty?
        else
          if !options[:hide_choices]
            table border: false do
              row header: true do
                column "", width: 4
                column options[:choice_name].capitalize, width: 40
                column "Shortcut", width:10 unless options[:hide_shortcuts]
              end
              choices.each_with_index do |choice, index|
                row do
                  column "(#{index})", align: 'right', width: 4
                  column "#{choice[:display]}", width: 40
                  column "#{choice[:shortcut] || 'n/a'}", width: 10 unless options[:hide_shortcuts]
                end
              end
            end
          end

          selected_indices = ask(options[:question]).split(" ")

          if selected_indices.length != 1 && options[:select_one]
            say Rainbow("Please choose only one #{options[:choice_name]}! (or CTRL + C to exit)").red
            options[:hide_choices] = true
            selections = select(choices, question, options)
          elsif selected_indices.any? {|si| !si.is_i?}
            say Rainbow("Please enter a number or numbers separated by spaces! (or CTRL + C to exit)").red
            options[:hide_choices] = true
            selections = select(choices, question, options)
          elsif selected_indices.empty?
            say Rainbow("Please choose at least one #{options[:choice_name]}! (or CTRL + C to exit)").red
            selections = select(choices, question, options)
          else
            selections = selected_indices.collect{|si| choices[si.to_i][:value]}.flatten
          end
        end

        return selections.flatten
      end
    end



  end
end
