require 'dotenv/load'
require 'rest-client'
require 'json'
require_relative 'maze_bot/client'
require_relative 'maze_bot/keyboard'
require_relative 'maze_bot/maze_generator'
require_relative 'maze_bot/message_handler'

module MazeBot
  class Runner
    def self.run
      token = ENV['VK_TOKEN']
      client = MazeBot::Client.new(token)
      keyboard = MazeBot::Keyboard.default
      handler = MazeBot::MessageHandler.new(client, keyboard)

      puts "Бот запущен! Генерирую лабиринты..."

      last_message_id = 0

      loop do
        begin
          response = client.api_call('messages.getConversations', {
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

          handler.process_messages(items)

          sleep 1
        rescue => e
          puts "Ошибка: #{e.message}"
          sleep 5
        end
      end
    end
  end
end

# Запускаем бота
MazeBot::Runner.run if __FILE__ == $PROGRAM_NAME