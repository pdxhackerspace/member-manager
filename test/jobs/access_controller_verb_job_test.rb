require 'test_helper'

class AccessControllerVerbJobTest < ActiveSupport::TestCase
  setup do
    @access_controller = AccessController.create!(
      name: 'Laser 1',
      hostname: 'laser1.local',
      access_controller_type: access_controller_types(:laser_controller)
    )
    @user = users(:one)
  end

  test 'build_env converts user name and username to ASCII' do
    @user.update!(full_name: 'José García', username: 'josé')

    env = AccessControllerVerbJob.new.send(:build_env, @access_controller, @user.id)

    assert_equal 'Jose Garcia', env['MM_USER_NAME']
    assert_equal 'jose', env['MM_USER_USERNAME']
  end

  test 'build_env omits username when it cannot be represented in ASCII' do
    @user.update!(username: '用户')

    env = AccessControllerVerbJob.new.send(:build_env, @access_controller, @user.id)

    assert_not env.key?('MM_USER_USERNAME')
  end
end
