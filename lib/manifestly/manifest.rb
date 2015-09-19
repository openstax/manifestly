require_relative './manifest_item'

module Manifestly
  class Manifest

    def initialize()
      @items = []
    end

    def add_repository(repository)
      @items.push(Manifestly::ManifestItem.new(repository))
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
        @items.each do |item|
          file.write(item.to_file_string + "\n")
        end
      end
    end

    attr_reader :items

    def empty?
      items.empty?
    end

  end
end
