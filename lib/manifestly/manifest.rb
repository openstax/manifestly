require_relative './manifest_item'

module Manifestly
  class Manifest

    def initialize()
      @items = []
    end

    def add_repository(repository)
      @items.push(Manifestly::ManifestItem.new(repository))
    end

    def remove_repository(repository)
      @items.reject!{|item| item.repository.display_name == repository.display_name}
    end

    def add_item(manifest_item)
      @items.push(manifest_item)
    end

    def remove_repositories_by_index(indices)
      indices.each{|index| @items[index] = nil}
      @items.compact!
      nil
    end

    def [](index)
      @items[index]
    end

    def self.read(filename, repositories)
      manifest = Manifest.new

      File.open(filename, 'r') do |file|
        file.each_line do |line|
          item = ManifestItem.from_file_string(line, repositories)
          manifest.add_item(item)
        end
      end

      manifest
    end

    def write(filename)
      File.open(filename, 'w') do |file|
        @items.sort_by!(&:repository_name)
        @items.each do |item|
          file.write(item.to_file_string + "\n")
        end
      end
    end

    def includes?(repository)
      @items.any?{|item| item.repository.display_name == repository.display_name}
    end

    attr_reader :items

    def empty?
      items.empty?
    end

  end
end
