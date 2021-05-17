require 'rails_helper'

RSpec.feature 'USER views other profile', type: :feature do
  let(:first_user) { FactoryGirl.create(:user, name: 'Андрей') }
  let(:second_user) { FactoryGirl.create(:user, name: 'Антон') }

  # Создаём две игры принадлежащие пользователю 'Антон'
  let(:first_game) { FactoryGirl.create(:game_with_questions, user: second_user) }
  let(:second_game) { FactoryGirl.create(:game_with_questions, user: second_user) }

  let(:games) { [first_game, second_game] }

  before(:each) do
    # Логиним первого юзера 'Андрей' от него будем смотреть профиль другого юзера
    login_as first_user

    # ----------[ подготовка результатов 1-ой игры ]----------
    q = first_game.current_game_question
    first_game.created_at = 0.4.hour.ago
    first_game.current_level = 5
    first_game.answer_current_question!(q.correct_answer_key)
    first_game.take_money!

    # ----------[ подготовка результатов 2-ой игры ]----------
    q = second_game.current_game_question
    second_game.created_at = 0.4.hour.ago
    second_game.current_level = 14
    second_game.answer_current_question!(q['a'])
  end

  scenario 'user views other profile' do

  visit '/'

  click_link 'Антон'

  # URL пользователя 'Антон'
  expect(page).to have_current_path "/users/#{second_user.id}"
  # Имя текущего, залогиненного пользователя
  expect(page).to have_content 'Андрей'
  # Имя игрока на чьей странице мы находимся
  expect(page).to have_content 'Антон'
  # Не видим ссылку на смену пароля, так как на чужой странице
  expect(page).to_not have_content 'Сменить имя и пароль'

  # ------------------------[ 1 игра ]------------------------
  # Порядковый номер игры
  expect(page).to have_content '1'
  # Статус
  expect(page).to have_content 'деньги'
  # Дата
  expect(page).to have_content I18n.l(first_game.created_at, format: :short)
  # Вопрос
  expect(page).to have_content '6'
  # Выигрыш
  expect(page).to have_content '2 000 ₽'

  # ------------------------[ 2 игра ]------------------------
  # Порядковый номер игры
  expect(page).to have_content '2'
  # Статус
  expect(page).to have_content 'проигрыш'
  # Дата
  expect(page).to have_content I18n.l(second_game.created_at, format: :short)
  # Вопрос
  expect(page).to have_content '14'
  # Выигрыш
  expect(page).to have_content '32 000 ₽'

  # save_and_open_page
  end
end
