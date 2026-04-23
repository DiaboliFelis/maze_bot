require 'json'

module MazeBot
  class Storage
    def initialize(file_path = 'bot_state.json')
      @file_path = file_path
    end

    def save(data)
      # Преобразуем все ключи в строки, чтобы избежать дублирования
      sanitized = JSON.parse(JSON.generate(data))
      File.write(@file_path, JSON.pretty_generate(sanitized))
    rescue => e
      puts "Ошибка сохранения: #{e.message}"
    end

    def load
      if File.exist?(@file_path)
        data = JSON.parse(File.read(@file_path))
        # Преобразуем строковые ключи в символы только для первого уровня
        symbolize_keys(data)
      else
        {}
      end
    rescue => e
      puts "Ошибка загрузки: #{e.message}"
      {}
    end

    private

    def symbolize_keys(hash)
      new_hash = {}
      hash.each do |key, value|
        new_key = key.to_sym
        new_hash[new_key] = value.is_a?(Hash) ? symbolize_keys(value) : value
      end
      new_hash
    end
  end
end