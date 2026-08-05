require 'test_helper'

class ApplicationLayoutTest < ActionDispatch::IntegrationTest
  test 'footer includes GitHub link when GITHUB_REPOSITORY_URL is set' do
    with_env('GITHUB_REPOSITORY_URL' => 'https://github.com/example/member-zone') do
      get login_path

      assert_response :success
      assert_select 'footer a[href=?]', 'https://github.com/example/member-zone', text: 'GitHub'
    end
  end

  test 'footer omits GitHub link when GITHUB_REPOSITORY_URL is blank' do
    with_env('GITHUB_REPOSITORY_URL' => nil) do
      get login_path

      assert_response :success
      assert_select 'footer a', text: 'GitHub', count: 0
    end
  end

  private

  def with_env(values)
    originals = values.keys.index_with { |key| ENV.fetch(key, nil) }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    originals.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
