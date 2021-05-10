# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryGirl.create(:user) }
  # админ
  let(:admin) { FactoryGirl.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  # группа тестов для незалогиненного юзера (Анонимус)
  context 'Anon' do
    # из экшена show анона посылаем
    it 'kick from #show' do
      # вызываем экшен
      get :show, id: game_w_questions.id
      # проверяем ответ
      expect(response.status).to eq(302) # статус не 200 ОК
      expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
      expect(flash[:alert]).to be # во flash должен быть прописана ошибка
    end

    it 'kick from #create' do
      expect { post :create }.to change(Game, :count).by(0)
      game = assigns(:game)
      expect(game).to be_nil

      expect(response.status).to eq(302)
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq("Вам необходимо войти в систему или зарегистрироваться.")
    end

    it 'kick from #answer' do
      put :answer, id: game_w_questions.id, letter: 'a'
      game = assigns(:game)
      expect(game).to be_nil

      expect(response.status).to eq(302)
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq("Вам необходимо войти в систему или зарегистрироваться.")
    end

    it 'kick from #take_money' do
      game_w_questions.update_attribute(:current_level, 2)

      put :take_money, id: game_w_questions.id
      game = assigns(:game)
      expect(game).to be_nil

      expect(response.status).to eq(302)
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq("Вам необходимо войти в систему или зарегистрироваться.")
    end

    it 'kick from #help' do
      expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
      expect(game_w_questions.audience_help_used).to be false

      put :help, id: game_w_questions.id, help_type: :audience_help
      game = assigns(:game)
      expect(game).to be_nil

      expect(response.status).to eq(302)
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq("Вам необходимо войти в систему или зарегистрироваться.")
    end
  end

  # группа тестов на экшены контроллера, доступных залогиненным юзерам
  context 'Usual user' do
    # перед каждым тестом в группе
    before(:each) { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in

    # юзер может создать новую игру
    it 'creates game' do
      # сперва накидаем вопросов, из чего собирать новую игру
      generate_questions(15)

      post :create
      game = assigns(:game) # вытаскиваем из контроллера поле @game

      # проверяем состояние этой игры
      expect(game.finished?).to be false
      expect(game.user).to eq(user)
      # и редирект на страницу этой игры
      expect(response).to redirect_to(game_path(game))
      expect(flash[:notice]).to be
    end

    # юзер видит свою игру
    it '#show game' do
      get :show, id: game_w_questions.id
      game = assigns(:game) # вытаскиваем из контроллера поле @game
      expect(game.finished?).to be false
      expect(game.user).to eq(user)

      expect(response.status).to eq(200) # должен быть ответ HTTP 200
      expect(response).to render_template('show') # и отрендерить шаблон show
    end

    it '#show game of another user' do
      # создаем новую игру, юзер не прописан, будет создан фабрикой новый
      another_users_game = FactoryGirl.create(:game_with_questions)

      # пробуем зайти на эту игру текущий залогиненным user
      get :show, id: another_users_game.id

      expect(response.status).to eq(302) # статус не 200 ОК
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be # во flash должена быть прописана ошибка
    end

    # юзер отвечает на игру корректно - игра продолжается
    it 'answers correct' do
      # передаем параметр params[:letter]
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
      game = assigns(:game)

      expect(game.finished?).to be false
      expect(game.current_level).to be > 0

      expect(response.status).to eq(302)
      expect(response).to redirect_to(game_path(game))
      expect(flash.empty?).to be true # удачный ответ не заполняет flash
    end

    it 'wrong answer' do
      put :answer, id: game_w_questions.id, letter: 'a'
      game = assigns(:game)

      expect(game.finished?).to be true
      expect(game.current_level).to eq(0)

      expect(response.status).to eq(302)
      expect(response).to redirect_to(user_path(user))

      expect(flash.empty?).to be false
    end

    # тест на отработку "помощи зала"
    it 'uses audience help' do
      # сперва проверяем что в подсказках текущего вопроса пусто
      expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
      expect(game_w_questions.audience_help_used).to be false

      # фигачим запрос в контроллен с нужным типом
      put :help, id: game_w_questions.id, help_type: :audience_help
      game = assigns(:game)

      # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
      expect(game.finished?).to be false
      expect(game.audience_help_used).to be true
      expect(game.current_game_question.help_hash[:audience_help]).to be
      expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
      expect(response.status).to eq(302)
      expect(response).to redirect_to(game_path(game))
    end

    it 'take_money' do
      game_w_questions.update_attribute(:current_level, 2)

      put :take_money, id: game_w_questions.id
      game = assigns(:game)
      expect(game.finished?).to be true
      expect(game.prize).to eq(200)
    end

    it 'dont create second game' do
      expect(game_w_questions.finished?).to be false

      expect { post :create }.to change(Game, :count).by(0)
      game = assigns(:game)
      expect(game).to be_nil

      expect(response).to redirect_to(game_path(game_w_questions))
      expect(flash[:alert]).to be
    end

    it 'uses fifty_fifty help' do
      expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
      expect(game_w_questions.fifty_fifty_used).to be false

      put :help, id: game_w_questions.id, help_type: :fifty_fifty
      game = assigns(:game)

      expect(game.finished?).to be false
      expect(game.fifty_fifty_used).to be true

      fifty_fifty_answer = game.current_game_question.help_hash[:fifty_fifty]
      expect(fifty_fifty_answer).to be
      expect(fifty_fifty_answer).to contain_exactly('d', fifty_fifty_answer.last)
      expect(response.status).to eq(302)
      expect(response).to redirect_to(game_path(game))
    end
  end
end
