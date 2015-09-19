require_relative './manifest_item'

class Manifestly::Manifest

  def initialize()
    @items = []
  end

  def add_repository(repository)
    @items.push(Manifestly::ManifestItem.new(repository))
  end

  def remove_repositories_by_index(indices)
    indices.each{|index| @items[index] = nil}
    @items.compact!
    nil
  end

  def [](index)
    @items[index]
  end

  def write(filename)
    File.open(filename, 'w') do |file|
      @items.each do |item|
        file.write(item.to_file_string)
      end
    end
  end

  attr_reader :items

  def empty?
    items.empty?
  end

end
