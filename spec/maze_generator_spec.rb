require 'spec_helper'
require_relative '../lib/maze_bot/maze_generator'

RSpec.describe MazeBot::MazeGenerator do
  describe '.generate' do
    it 'создаёт лабиринт 5x5' do
      maze = described_class.generate(5, 5)
      expect(maze).to respond_to(:rows)
      expect(maze.rows).to eq(5)
      expect(maze.cols).to eq(5)
    end

    it 'создаёт лабиринт 10x15' do
      maze = described_class.generate(10, 15)
      expect(maze.rows).to eq(10)
      expect(maze.cols).to eq(15)
    end
  end

  describe '.to_png' do
    it 'сохраняет PNG файл' do
      maze = described_class.generate(3, 3)
      filename = 'test_maze.png'
      described_class.to_png(maze, filename)
      expect(File.exist?(filename)).to be true
      File.delete(filename) if File.exist?(filename)
    end
  end
end