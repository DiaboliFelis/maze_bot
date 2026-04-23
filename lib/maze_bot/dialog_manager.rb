module MazeBot
  class DialogManager
    def initialize
      @users = {}
    end

    def load_state(state)
      @users = state
    end

    def save_state
      @users
    end

    def active_dialogs
      @users
    end

    def active_dialog?(peer_id)
      @users.key?(peer_id)
    end

    def start_maze_creation(peer_id)
      @users[peer_id] = { step: :awaiting_rows }
      "Введите количество рядов (от 2 до 50):"
    end

    def process_input(peer_id, text)
      user = @users[peer_id]
      return nil unless user

      case user[:step]
      when :awaiting_rows
        rows = text.to_i
        if rows < 2 || rows > 50
          return "❌ Ошибка: количество рядов должно быть от 2 до 50. Попробуй ещё раз:"
        end
        user[:rows] = rows
        user[:step] = :awaiting_cols
        return "Отлично! Теперь введите количество колонок (от 2 до 50):"

      when :awaiting_cols
        cols = text.to_i
        if cols < 2 || cols > 50
          return "❌ Ошибка: количество колонок должно быть от 2 до 50. Попробуй ещё раз:"
        end
        rows = user[:rows]
        @users.delete(peer_id)
        return { action: :generate_maze, rows: rows, cols: cols }

      else
        @users.delete(peer_id)
        return nil
      end
    end
  end
end