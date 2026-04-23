require_relative 'dialog_manager'
require_relative 'storage'
require_relative 'message_store'

module MazeBot
  class MessageHandler
    def initialize(client, keyboard)
      @client = client
      @keyboard = keyboard
      @storage = Storage.new
      @message_store = MessageStore.new
      @last_mazes = {}
      @first_time_users = {}
      @last_message_id = 0
      @dialog_manager = DialogManager.new

      load_state
      resume_from_history

      if @last_message_text && !@last_message_text.empty?
    puts "Обрабатываю сохранённое сообщение: #{@last_message_text}"
    # Имитируем обработку сообщения
    process_saved_message(@last_message_text)
  end
    end

    # восстанавливает диалог из сохранённой истории
    def resume_from_history
      messages = @message_store.load_all
      return if messages.empty?
      
      messages.each do |peer_id, history|
        next if history.empty?
        
        # Находим последнее сообщение пользователя
        last_user_msg = history.reverse.find { |m| !m['from_bot'] }
        next unless last_user_msg
        
        last_bot_msg = history.reverse.find { |m| m['from_bot'] }
        
        # Определяем состояние диалога
        if last_bot_msg && last_bot_msg['text'].include?('количество рядов')
          # Бот ждёт ряды
          @dialog_manager.start_maze_creation(peer_id)
          @client.send_message(peer_id, "Введите количество рядов (от 2 до 50):", @keyboard)
          puts "Восстановлен диалог для #{peer_id}: ожидание рядов"
          
        elsif last_bot_msg && last_bot_msg['text'].include?('количество колонок')
          # Бот ждёт колонки
          rows = last_user_msg['text'].to_i
          @dialog_manager.start_maze_creation(peer_id)
          @dialog_manager.instance_variable_get(:@users)[peer_id][:rows] = rows
          @dialog_manager.instance_variable_get(:@users)[peer_id][:step] = :awaiting_cols
          @client.send_message(peer_id, "Отлично! Теперь введите количество колонок (от 2 до 50):", @keyboard)
          puts "Восстановлен диалог для #{peer_id}: ожидание колонок (rows=#{rows})"
          
        elsif last_user_msg && !last_bot_msg
          # Новый пользователь — отправляем приветствие
          @first_time_users[peer_id] = true
          send_welcome(peer_id)
      
        elsif last_bot_msg && last_bot_msg['text'].include?('Генерирую лабиринт')
          # Последнее действие — генерация, не повторяем
          puts "Последнее действие — генерация лабиринта, пропускаем восстановление"
          @dialog_manager.instance_variable_get(:@users).delete(peer_id)

        elsif last_bot_msg && last_bot_msg['text'].start_with?('🏁 Генерирую лабиринт')
          # Генерация уже была — просто очищаем диалог
          puts "Последнее действие — генерация лабиринта, очищаем диалог"
          @dialog_manager.instance_variable_get(:@users).delete(peer_id)
        end
      end
    end

    def process_saved_message(text)
  # логика обработки сообщения
  peer_id = @dialog_manager.active_dialogs.keys.first
  return unless peer_id
  
  dialog_response = @dialog_manager.process_input(peer_id, text)
  if dialog_response
    if dialog_response.is_a?(Hash) && dialog_response[:action] == :generate_maze
      generate_and_send_maze(peer_id, dialog_response[:rows], dialog_response[:cols])
    else
      @client.send_message(peer_id, dialog_response, @keyboard)
    end
  end
end


    def process_messages(messages)
      messages.each do |item|
        next unless item['last_message']

        message = item['last_message']
        next if message['id'] <= @last_message_id
        @last_message_id = message['id'] if message['id'] > @last_message_id
        next if message['out'] == 1

        text = message['text'].to_s.downcase
        peer_id = message['peer_id'].to_s.strip

        # Сохраняем сообщение пользователя
        @message_store.save_message(peer_id, text, false)

        @last_message_text = text 

        # Приветствие
#         if @first_time_users[peer_id].nil?
#           puts "DEBUG: Отправляю приветствие для #{peer_id}, first_time_users=#{@first_time_users.inspect}"
#   @first_time_users[peer_id] = true
#   send_welcome(peer_id)
#   save_state
#   next
# end
        if @first_time_users[peer_id].nil?
          @first_time_users[peer_id] = true
          send_welcome(peer_id)
          save_state
        end

        # Обработка payload от кнопок
        if message['payload']
          payload = JSON.parse(message['payload'])
          case payload['command']
          when 'maze'
            response = @dialog_manager.start_maze_creation(peer_id)
            @client.send_message(peer_id, response, @keyboard)
            @message_store.save_message(peer_id, response, true)
            next
          when 'solve'
            text = 'реши'
          when 'help'
            help_msg = help_text
            @client.send_message(peer_id, help_msg, @keyboard)
            @message_store.save_message(peer_id, help_msg, true)
            next
          end
        end

        # Проверяем, есть ли активный диалог
        dialog_response = @dialog_manager.process_input(peer_id, text)
        if dialog_response
          if dialog_response.is_a?(Hash) && dialog_response[:action] == :generate_maze
            generate_and_send_maze(peer_id, dialog_response[:rows], dialog_response[:cols])
          else
            @client.send_message(peer_id, dialog_response, @keyboard)
            @message_store.save_message(peer_id, dialog_response, true)
          end
          save_state
          next
        end

        # Команда помощи
        if ['помощь', 'help', 'start', 'начать'].include?(text)
          @client.send_message(peer_id, help_text, @keyboard)
          @message_store.save_message(peer_id, help_text, true)
          next
        end

        # Команда "реши"
        if text == 'реши' || text == 'решить' || text == 'путь' || text == 'solve'
          handle_solve(peer_id)
          next
        end

        # Команда лабиринта (для обратной совместимости)
        if text.start_with?('лабиринт')
          match = text.match(/(\d+)\s*[хx×]\s*(\d+)/)
          if match
            rows = match[1].to_i
            cols = match[2].to_i
            generate_and_send_maze(peer_id, rows, cols)
          else
            msg = "❌ Не понял размер.\nПример: лабиринт 8х8"
            @client.send_message(peer_id, msg, @keyboard)
            @message_store.save_message(peer_id, msg, true)
          end
          next
        end

        # Неизвестная команда
        msg = "❌ Неизвестная команда.\nНажми на кнопки или напиши: помощь"
        @client.send_message(peer_id, msg, @keyboard)
        @message_store.save_message(peer_id, msg, true)
      end
      save_state
    end

    private

    def load_state
  data = @storage.load
 @first_time_users = (data[:first_time_users] || {}).transform_keys(&:to_s)
  @last_mazes = data[:last_mazes] || {}
  @last_message_id = data[:last_message_id] || 0
  @dialog_manager.load_state((data[:dialogs] || {}).transform_keys(&:to_sym))
  @last_message_text = data[:last_message_text] || ""
  
  puts "Загружено first_time_users: #{@first_time_users.inspect}"
  puts "Загружено dialogs: #{@dialog_manager.save_state.inspect}"
end

    def save_state
      data = {
        first_time_users: @first_time_users,
        last_mazes: @last_mazes,
        last_message_id: @last_message_id,
        dialogs: @dialog_manager.save_state,
        last_message_text: @last_message_text,
      }
      @storage.save(data)
    end

    def send_welcome(peer_id)
      @client.send_message(peer_id, "👋 Привет! Я бот-генератор лабиринтов.\nКоманды:\n
🏁 `Создать лабиринт`\n
🧭 `реши` — найти путь в последнем лабиринте\n
📖 `помощь` — показать справку»", @keyboard)
    end

    def generate_and_send_maze(peer_id, rows, cols)
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

        @dialog_manager.instance_variable_get(:@users).delete(peer_id)
        @message_store.save_message(peer_id, "[Генерация завершена]", true)

      rescue => e
        puts "Ошибка генерации: #{e.message}"
        @client.send_message(peer_id, "❌ Ошибка при генерации.", @keyboard)
      end
    end

    def handle_solve(peer_id)
      unless @last_mazes[peer_id]
        @client.send_message(peer_id, "❌ Нет сохранённого лабиринта.\nСначала создай лабиринт", @keyboard)
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
        @message_store.save_message(peer_id, "[Отправлена картинка с путём]", true)

        File.delete(filename)

        @dialog_manager.instance_variable_get(:@users).delete(peer_id)

      rescue => e
        puts "Ошибка поиска пути: #{e.message}"
        @client.send_message(peer_id, "❌ Ошибка при поиске пути.", @keyboard)
      end
    end

    def help_text
      <<~HELP
        🧩 *Генератор лабиринтов*

        *Команды:*
        🏁 Создать лабиринт — нажми на кнопку
        🧭 Решить лабиринт — найти путь в последнем лабиринте
        📖 Помощь — показать справку
      HELP
    end
  end
end