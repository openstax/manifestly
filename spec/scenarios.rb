require 'tmpdir'
require 'erb'
require 'fileutils'

class Scenarios

  def self.run(name, &block)
    new.run(name, &block)
  end

  def run(name_or_options, &block)
    @dir = Dir.mktmpdir('manifestly-spec-')
    @fixtures_dir = absolutize_gem_path("./spec/fixtures")

    begin
      Manifestly.configuration.cached_repos_root_dir = @dir

      scenario = name_or_options.is_a?(Hash) ?
                   name_or_options[:inline] :
                   File.open(absolutize_gem_path("./spec/fixtures/scenarios/#{name_or_options}.scenario")).read

      scenario = scenario.split("\n").collect(&:strip).join("\n")
      scenario = "cd #{@dir}\n" + scenario
      scenario = Scenarios.sub_aliases(scenario)
      scenario = ERB.new(scenario).result(binding())

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

  def self.sub_aliases(scenario)
    scenario.split("\n").collect do |line|
      sub_fake_commit(line)
    end.join("\n")
  end

  def self.sub_fake_commit(line)
    return line if !line.starts_with?("fake_commit")

    options = parse_alias(line)

    [
      "cd #{options[:repo]}",
      "touch foo",
      "echo #{SecureRandom.hex(3)} >> foo",
      "git add . && git commit -q -m '#{options[:comment]}'",
      options[:sha] ? "#{options[:sha]}=\"$(git rev-parse HEAD)\"" : nil,
      "cd .."
    ].compact.join("\n")
  end

  def self.parse_alias(line)
    options = line.split("|")
    options = options[1..-1]  # ditch alias name
    options = options.collect(&:strip)
    options = options.each_with_object({}) do |option, hash|
      parts = option.split(":").collect(&:strip)
      hash[parts[0].to_sym] = parts[1]
    end
  end


end
