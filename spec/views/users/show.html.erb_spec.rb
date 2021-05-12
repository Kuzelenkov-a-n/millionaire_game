require 'rails_helper'

RSpec.describe 'users/show', type: :view do
  before(:each) do
    current_user = assign(:user, FactoryGirl.build_stubbed(:user, name: 'Андрей'))
    allow(view).to receive(:current_user).and_return(current_user)

    render
  end

  it 'renders user name' do
    expect(rendered).to match 'Андрей'
  end

  it 'renders change password button' do
    expect(rendered).to match 'Сменить имя и пароль'
  end

  it 'renders game partial' do
    assign(:games, [FactoryGirl.build_stubbed(:game)])
    stub_template 'users/_game.html.erb' => 'Тут игра'

    render
    expect(rendered).to match 'Тут игра'
  end
end
