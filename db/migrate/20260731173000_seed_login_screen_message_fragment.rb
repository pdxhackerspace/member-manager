class SeedLoginScreenMessageFragment < ActiveRecord::Migration[8.1]
  def up
    TextFragment.ensure_exists!(
      key: 'login_screen_message',
      title: 'Login Screen Message',
      content: ''
    )
  end

  def down
    TextFragment.find_by(key: 'login_screen_message')&.destroy
  end
end
