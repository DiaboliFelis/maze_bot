require 'the_labyrinths'

module MazeBot
  class MazeGenerator
    def self.generate(rows, cols)
      TheLabyrinths.generate(rows: rows, cols: cols)
    end

    def self.to_png(maze, filename, cell_size = 20)
      maze.to_png(filename, cell_size: cell_size)
    end

    def self.to_png_with_path(maze, filename, path, cell_size = 20)
      maze.to_png_with_path(filename, cell_size: cell_size, path: path)
    end
  end
end