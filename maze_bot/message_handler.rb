require 'set'

module MazeBot
  class MessageHandler
    attr_reader :client, :keyboard, :last_mazes

    def initialize(client, keyboard)
      @client = client
      @keyboard = keyboard
      @last_mazes = {}
      @first_time_users = {}
      @last_message_id = 0
    end

    def process_messages(messages)
      messages.each do |item|
        next unless item['last_message']

        message = item['last_message']
        next if message['id'] <= @last_message_id
        @last_message_id = message['id'] if message['id'] > @last_message_id
        next if message['out'] == 1

        text = message['text'].to_s.downcase
        peer_id = message['peer_id']

        # Приветствие
        unless @first_time_users[peer_id]
          @first_time_users[peer_id] = true
          send_welcome(peer_id)
          next
        end

        # Обработка payload от кнопок
        if message['payload']
          payload = JSON.parse(message['payload'])
          case payload['command']
          when 'solve'
            text = 'реши'
          when 'help'
            @client.send_message(peer_id, help_text, @keyboard)
            next
          end
        end

        # Команда помощи
        if ['помощь', 'help', 'start', 'начать'].include?(text)
          @client.send_message(peer_id, help_text, @keyboard)
          next
        end

        # Команда "реши"
        if text == 'реши' || text == 'решить' || text == 'путь' || text == 'solve'
          handle_solve(peer_id)
          next
        end

        # Команда лабиринта
        if text.start_with?('лабиринт')
          handle_maze(peer_id, text)
          next
        end

        # Неизвестная команда
        @client.send_message(peer_id, "❌ Неизвестная команда.\nНапиши: лабиринт 8х8 или помощь", @keyboard)
      end
    end

    private

    def send_welcome(peer_id)
      @client.send_message(peer_id, "👋 Привет! Я бот-генератор лабиринтов.\n\nСоздай лабиринт командой: лабиринт 8х8\nА потом напиши: реши")
      @client.send_message(peer_id, "Кнопки:", @keyboard)
    end

    def handle_maze(peer_id, text)
      match = text.match(/(\d+)\s*[хx×]\s*(\d+)/)

      unless match
        @client.send_message(peer_id, "❌ Не понял размер.\nПример: лабиринт 8х8", @keyboard)
        return
      end

      rows = match[1].to_i
      cols = match[2].to_i

      if rows < 2 || cols < 2
        @client.send_message(peer_id, "❌ Минимальный размер — 2×2", @keyboard)
        return
      end

      if rows > 50 || cols > 50
        @client.send_message(peer_id, "❌ Максимальный размер — 50×50!", @keyboard)
        return
      end

      @client.send_message(peer_id, "🏁 Генерирую лабиринт #{rows}×#{cols}...", @keyboard)

      begin
        maze = MazeGenerator.generate(rows, cols)
        filename = "maze_#{rows}_#{cols}.png"
        MazeGenerator.to_png(maze, filename)

        @last_mazes[peer_id] = { rows: rows, cols: cols, maze: maze }

        upload_server = @client.api_call('photos.getMessagesUploadServer')
        upload_url = upload_server['response']['upload_url']

        upload_result = RestClient.post(upload_url, photo: File.new(filename))
        photo_data = JSON.parse(upload_result)

        save_response = @client.api_call('photos.saveMessagesPhoto', {
          photo: photo_data['photo'],
          server: photo_data['server'],
          hash: photo_data['hash']
        })

        if save_response['error']
          @client.send_message(peer_id, "❌ Не удалось загрузить картинку.", @keyboard)
          File.delete(filename) if File.exist?(filename)
          return
        end

        photo = save_response['response'][0]
        attachment = "photo#{photo['owner_id']}_#{photo['id']}"
        @client.send_photo(peer_id, attachment)

        File.delete(filename)
      rescue => e
        puts "Ошибка генерации: #{e.message}"
        @client.send_message(peer_id, "❌ Ошибка при генерации.", @keyboard)
      end
    end

    def handle_solve(peer_id)
      unless @last_mazes[peer_id]
        @client.send_message(peer_id, "❌ Нет сохранённого лабиринта.\nСначала создай лабиринт командой: лабиринт 8х8", @keyboard)
        return
      end

      last = @last_mazes[peer_id]
      rows, cols, maze = last[:rows], last[:cols], last[:maze]

      @client.send_message(peer_id, "🧭 Ищу путь в лабиринте #{rows}×#{cols}...", @keyboard)

      begin
        path = maze.solve
        if path.empty?
          @client.send_message(peer_id, "❌ Путь не найден!", @keyboard)
          return
        end

        filename = "maze_solved_#{rows}_#{cols}.png"
        MazeGenerator.to_png_with_path(maze, filename, path)

        upload_server = @client.api_call('photos.getMessagesUploadServer')
        upload_url = upload_server['response']['upload_url']
        upload_result = RestClient.post(upload_url, photo: File.new(filename))
        photo_data = JSON.parse(upload_result)

        save_response = @client.api_call('photos.saveMessagesPhoto', {
          photo: photo_data['photo'],
          server: photo_data['server'],
          hash: photo_data['hash']
        })

        if save_response['error']
          @client.send_message(peer_id, "❌ Не удалось загрузить картинку с путём.", @keyboard)
          File.delete(filename) if File.exist?(filename)
          return
        end

        photo = save_response['response'][0]
        attachment = "photo#{photo['owner_id']}_#{photo['id']}"
        @client.send_message(peer_id, "🧩 Путь найден! Длина: #{path.length} шагов", @keyboard)
        @client.send_photo(peer_id, attachment)

        File.delete(filename)
      rescue => e
        puts "Ошибка поиска пути: #{e.message}"
        @client.send_message(peer_id, "❌ Ошибка при поиске пути.", @keyboard)
      end
    end

    def help_text
      <<~HELP
        🧩 *Генератор лабиринтов*

        *Команды:*
        🏁 `лабиринт ?х?` — создать лабиринт
        🧭 `реши` — найти путь в последнем лабиринте
        📖 `помощь` — показать справку

        *Примеры:*
        - лабиринт 10х10
        - лабиринт 15x15
        - реши
      HELP
    end
  end
end