require 'json'

module MazeBot
  class MessageStore
    def initialize(file_path = 'messages.json')
      @file_path = file_path
    end

    def save_message(peer_id, text, from_bot = false)
      messages = load_all
      messages[peer_id.to_s] ||= []
      messages[peer_id.to_s] << {
        text: text,
        from_bot: from_bot,
        timestamp: Time.now.to_i
      }
      # Оставляем только последние 50 сообщений на диалог
      messages[peer_id.to_s] = messages[peer_id.to_s].last(50)
      File.write(@file_path, JSON.pretty_generate(messages))
    end

    def load_all
      if File.exist?(@file_path)
        JSON.parse(File.read(@file_path))
      else
        {}
      end
    end

    def get_last_message(peer_id)
      messages = load_all
      messages[peer_id.to_s]&.last
    end

    def get_last_user_message(peer_id)
      messages = load_all
      messages[peer_id.to_s]&.reverse&.find { |m| !m['from_bot'] }
    end

    def get_dialog_state(peer_id)
      messages = load_all
      user_msgs = messages[peer_id.to_s]&.select { |m| !m['from_bot'] } || []
      bot_msgs = messages[peer_id.to_s]&.select { |m| m['from_bot'] } || []
      
      # Анализируем последние сообщения
      last_user_msg = user_msgs.last
      last_bot_msg = bot_msgs.last
      
      if last_bot_msg && last_bot_msg['text'].include?('количество рядов')
        return :awaiting_rows
      elsif last_bot_msg && last_bot_msg['text'].include?('количество колонок')
        return :awaiting_cols
      end
      
      nil
    end
  end
end