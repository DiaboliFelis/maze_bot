require 'spec_helper'
require 'maze_bot/client'

RSpec.describe MazeBot::Client do
  let(:token) { 'test_token' }
  let(:client) { described_class.new(token) }

  describe '#initialize' do
    it 'создаёт клиент с токеном' do
      expect(client).to be_a(MazeBot::Client)
    end
  end

  describe '#api_call' do
    it 'выполняет запрос к API' do
      # Мокаем RestClient.post, чтобы он возвращал объект с методом body
      mock_response = double('response', body: '{"response":{}}')
      allow(RestClient).to receive(:post).and_return(mock_response)
      
      response = client.api_call('test.method')
      expect(response).to be_a(Hash)
      expect(response['response']).to eq({})
    end
  end
end