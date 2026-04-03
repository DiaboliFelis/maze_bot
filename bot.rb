require 'the_labyrinths'
require 'rest-client'
require 'json'
require 'dotenv/load'

TOKEN = ENV['VK_TOKEN']

def api_call(method, params = {})
  params[:access_token] = TOKEN
  params[:v] = '5.199'
  
  response = RestClient.post("https://api.vk.com/method/#{method}", params)
  JSON.parse(response.body)
end

def send_message(peer_id, text, keyboard = nil)
  params = {
    peer_id: peer_id,
    message: text,
    random_id: rand(1000000)
  }
  params[:keyboard] = keyboard.to_json if keyboard
  api_call('messages.send', params)
end

# Клавиатура с нужными кнопками (без генерации)
KEYBOARD = {
  one_time: false,
  buttons: [
    [
      {
        action: { type: "text", label: "🧭 Решить лабиринт", payload: "{\"command\":\"solve\"}" },
        color: "primary"
      },
      {
        action: { type: "text", label: "📖 Помощь", payload: "{\"command\":\"help\"}" },
        color: "secondary"
      }
    ]
  ]
}

HELP_TEXT = <<~HELP
🧩 *Генератор лабиринтов*

*Команды:*
🏁 `лабиринт ?х?` — создать лабиринт
   Пример: лабиринт 10х10

🧭 `реши` — найти путь в последнем лабиринте

📖 `помощь` — показать справку

*Как это работает:*
1. Создаёшь лабиринт (текстом)
2. Бот запоминает его
3. Пишешь `реши` — бот показывает путь
HELP

puts "Бот запущен! Генерирую лабиринты..."

last_message_id = 0
first_time_users = {}
$last_mazes = {}

loop do
  begin
    response = api_call('messages.getConversations', {
      count: 20,
      extended: 'all'
    })
    
    if response['error']
      puts "Ошибка API: #{response['error']['error_msg']}"
      sleep 5
      next
    end
    
    items = response['response']['items']
    next if items.empty?
    
    items.each do |item|
      next unless item['last_message']
      
      message = item['last_message']
      next if message['id'] <= last_message_id
      last_message_id = message['id'] if message['id'] > last_message_id
      
      next if message['out'] == 1
      
      text = message['text'].to_s.downcase
      peer_id = message['peer_id']
      
      # Приветствие новым пользователям
      unless first_time_users[peer_id]
        first_time_users[peer_id] = true
        send_message(peer_id, "👋 Привет! Я бот-генератор лабиринтов.\nКоманды:\n
🏁 `лабиринт ?х?` — создать лабиринт\n
🧭 `реши` — найти путь в последнем лабиринте\n
📖 `помощь` — показать справку", KEYBOARD)
        next
      end
      
      # Обработка payload от кнопок
      if message['payload']
        payload = JSON.parse(message['payload'])
        case payload['command']
        when 'solve'
          text = 'реши'
        when 'help'
          send_message(peer_id, HELP_TEXT, KEYBOARD)
          next
        end
      end
      
      # Команда помощи
      if ['помощь', 'help', 'start', 'начать'].include?(text)
        send_message(peer_id, HELP_TEXT, KEYBOARD)
        next
      end
      
      # Команда "реши"
      if text == 'реши' || text == 'решить' || text == 'путь' || text == 'solve'
        if $last_mazes[peer_id]
          last = $last_mazes[peer_id]
          rows, cols, maze = last[:rows], last[:cols], last[:maze]
          
          puts "Ищу путь в лабиринте #{rows}x#{cols}..."
          send_message(peer_id, "🧭 Ищу путь в лабиринте #{rows}×#{cols}...")
          
          begin
            path = maze.solve
            if path.empty?
              send_message(peer_id, "❌ Путь не найден!", KEYBOARD)
              next
            end
            
            filename = "maze_solved_#{rows}_#{cols}.png"
            maze.to_png_with_path(filename, cell_size: 20, path: path)
            
            upload_server = api_call('photos.getMessagesUploadServer')
            upload_url = upload_server['response']['upload_url']
            upload_result = RestClient.post(upload_url, photo: File.new(filename))
            photo_data = JSON.parse(upload_result)
            
            save_response = api_call('photos.saveMessagesPhoto', {
              photo: photo_data['photo'],
              server: photo_data['server'],
              hash: photo_data['hash']
            })
            
            if save_response['error']
              send_message(peer_id, "❌ Не удалось загрузить картинку с путём.", KEYBOARD)
              File.delete(filename) if File.exist?(filename)
              next
            end
            
            photo = save_response['response'][0]
            attachment = "photo#{photo['owner_id']}_#{photo['id']}"
            
            api_call('messages.send', {
              peer_id: peer_id,
              attachment: attachment,
              message: "🧩 Путь найден! Длина: #{path.length} шагов",
              random_id: rand(1000000)
            })
            
            File.delete(filename)
            puts "Путь отправлен!"
          rescue => e
            puts "Ошибка поиска пути: #{e.message}"
            send_message(peer_id, "❌ Ошибка при поиске пути.", KEYBOARD)
          end
        else
          send_message(peer_id, "❌ Нет сохранённого лабиринта.\nСначала создай лабиринт командой: лабиринт 8х8", KEYBOARD)
        end
        next
      end
      
      # Команда лабиринта (текстовая)
      if text.start_with?('лабиринт')
        match = text.match(/(\d+)\s*[хx]\s*(\d+)/)
        
        if match
          rows = match[1].to_i
          cols = match[2].to_i
          
          if rows < 2 || cols < 2
            send_message(peer_id, "❌ Минимальный размер — 2×2", KEYBOARD)
            next
          end
          
          if rows > 50 || cols > 50
            send_message(peer_id, "❌ Максимальный размер — 50×50!", KEYBOARD)
            next
          end
          
          puts "Генерирую лабиринт #{rows}x#{cols}..."
          send_message(peer_id, "🏁 Генерирую лабиринт #{rows}×#{cols}...")
          
          begin
            maze = TheLabyrinths.generate(rows: rows, cols: cols)
            filename = "maze_#{rows}_#{cols}.png"
            maze.to_png(filename, cell_size: 20)
            
            # Сохраняем лабиринт в памяти
            $last_mazes[peer_id] = { rows: rows, cols: cols, maze: maze }
            
            upload_server = api_call('photos.getMessagesUploadServer')
            upload_url = upload_server['response']['upload_url']
            upload_result = RestClient.post(upload_url, photo: File.new(filename))
            photo_data = JSON.parse(upload_result)
            
            save_response = api_call('photos.saveMessagesPhoto', {
              photo: photo_data['photo'],
              server: photo_data['server'],
              hash: photo_data['hash']
            })
            
            if save_response['error']
              send_message(peer_id, "❌ Не удалось загрузить картинку.", KEYBOARD)
              File.delete(filename) if File.exist?(filename)
              next
            end
            
            photo = save_response['response'][0]
            attachment = "photo#{photo['owner_id']}_#{photo['id']}"
            
            api_call('messages.send', {
              peer_id: peer_id,
              attachment: attachment,
              random_id: rand(1000000)
            })
            
            File.delete(filename)
            puts "Лабиринт отправлен!"
          rescue => e
            puts "Ошибка генерации: #{e.message}"
            send_message(peer_id, "❌ Ошибка при генерации.", KEYBOARD)
          end
        else
          send_message(peer_id, "❌ Не понял размер.\nПример: лабиринт 8х8", KEYBOARD)
        end
        next
      end
      
      # Неизвестная команда
      send_message(peer_id, "❌ Неизвестная команда.\nНапиши: лабиринт 8х8 или помощь", KEYBOARD)
    end
    
    sleep 1
  rescue => e
    puts "Ошибка: #{e.message}"
    sleep 5
  end
end