module MazeBot
  class Keyboard
    def self.default
      {
        one_time: false,
        buttons: [
          [
          {
              action: { type: "text", label: "🏁 Создать лабиринт", payload: "{\"command\":\"maze\"}" },
              color: "positive"
            },
          ],
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
    end
  end
end