require 'tmpdir'
require 'erb'
require 'fileutils'

class Scenarios

  def self.run(name, &block)
    new.run(name, &block)
  end

  def run(name, &block)
    @dir = Dir.mktmpdir('manifestly-spec-')
    @fixtures_dir = absolutize_gem_path("./spec/fixtures")

    begin
      Manifestly.configuration.cached_repos_root_dir = @dir

      scenario = name.is_a?(Hash) ?
                   name[:inline] :
                   File.open(absolutize_gem_path("./spec/fixtures/scenarios/#{name}.scenario")).read

      scenario = "cd #{@dir}\n" + scenario
      scenario = ERB.new(scenario).result(binding())
      # scenario = scenario.split("\n").collect{|line| line.starts_with?("git ") ? "#{line} &> /dev/null" : line}.join("\n")

      suppress_output { system scenario }

      dirs = {
        root: @dir,
        locals: "#{@dir}/locals",
        remotes: "#{@dir}/remotes"
      }

      block.call(dirs)
    rescue StandardError => e
      puts "Exception: #{e.inspect}"
      raise e
    ensure
      Manifestly.configuration.reset!
      FileUtils.rm_r @dir
    end
  end

end
