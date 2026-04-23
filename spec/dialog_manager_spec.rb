require 'spec_helper'
require_relative '../lib/maze_bot/dialog_manager'

RSpec.describe MazeBot::DialogManager do
  let(:manager) { described_class.new }
  let(:peer_id) { '123456' }

  describe '#start_maze_creation' do
    it 'возвращает запрос на ввод рядов' do
      response = manager.start_maze_creation(peer_id)
      expect(response).to include('количество рядов')
    end

    it 'сохраняет состояние пользователя' do
      manager.start_maze_creation(peer_id)
      expect(manager.active_dialog?(peer_id)).to be true
    end
  end

  describe '#process_input' do
    before { manager.start_maze_creation(peer_id) }

    it 'принимает корректное количество рядов' do
      response = manager.process_input(peer_id, '10')
      expect(response).to include('количество колонок')
    end

    it 'отклоняет ряды меньше 2' do
      response = manager.process_input(peer_id, '1')
      expect(response).to include('Ошибка')
    end

    it 'отклоняет ряды больше 50' do
      response = manager.process_input(peer_id, '51')
      expect(response).to include('Ошибка')
    end

    it 'принимает корректное количество колонок' do
      manager.process_input(peer_id, '10')
      response = manager.process_input(peer_id, '15')
      expect(response).to be_a(Hash)
      expect(response[:action]).to eq(:generate_maze)
    end
  end
end