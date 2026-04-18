require 'rest-client'
require 'json'

module MazeBot
  class Client
    def initialize(token, api_version = '5.199')
      @token = token
      @api_version = api_version
    end

    def api_call(method, params = {})
      params[:access_token] = @token
      params[:v] = @api_version

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

    def send_photo(peer_id, attachment)
      api_call('messages.send', {
        peer_id: peer_id,
        attachment: attachment,
        random_id: rand(1000000)
      })
    end
  end
end