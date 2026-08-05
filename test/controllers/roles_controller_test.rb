require 'test_helper'

class RolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    Privilege.seed_defaults!
    @topic = training_topics(:laser_cutting)
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'unauthenticated users are sent to login' do
    get roles_path

    assert_redirected_to login_path
  end

  test 'members cannot reach roles' do
    sign_in_as_member

    get roles_path

    assert_response :redirect
    assert_not_equal roles_path, response.location
  end

  test 'admin sees the roles index' do
    sign_in_as_admin
    Role.create!(name: 'Key fob manager', privileges: Privilege.where(key: 'access.manage_rfids'))

    get roles_path

    assert_response :success
    assert_match 'Key fob manager', response.body
  end

  test 'admin creates a role with privileges' do
    sign_in_as_admin
    privilege = Privilege.find_by!(key: 'access.manage_rfids')

    assert_difference 'Role.count', 1 do
      post roles_path, params: { role: { name: 'Fob team', description: 'Handles fobs',
                                         privilege_ids: [privilege.id] } }
    end

    assert_redirected_to roles_path
    assert_equal ['access.manage_rfids'], Role.find_by(name: 'Fob team').privilege_keys
  end

  test 'creating a role without a name fails' do
    sign_in_as_admin

    assert_no_difference 'Role.count' do
      post roles_path, params: { role: { name: '' } }
    end

    assert_response :unprocessable_content
  end

  test 'admin updates the privileges on a role' do
    sign_in_as_admin
    role = Role.create!(name: 'Editable', privileges: Privilege.where(key: 'access.manage_rfids'))
    replacement = Privilege.find_by!(key: 'payments.view')

    patch role_path(role), params: { role: { name: 'Editable', privilege_ids: [replacement.id] } }

    assert_redirected_to roles_path
    assert_equal ['payments.view'], role.reload.privilege_keys
  end

  # The form always submits a blank sentinel so unchecking everything clears the bundle.
  test 'clearing every privilege leaves the role empty' do
    sign_in_as_admin
    role = Role.create!(name: 'Emptied', privileges: Privilege.where(key: 'access.manage_rfids'))

    patch role_path(role), params: { role: { name: 'Emptied', privilege_ids: [''] } }

    assert_empty role.reload.privilege_keys
  end

  test 'admin deletes an unattached role' do
    sign_in_as_admin
    role = Role.create!(name: 'Unused')

    assert_difference 'Role.count', -1 do
      delete role_path(role)
    end
  end

  test 'a role attached to a topic cannot be deleted' do
    sign_in_as_admin
    role = Role.create!(name: 'Attached')
    TrainingTopicRole.create!(training_topic: @topic, role: role, member_source: 'trained_in')

    assert_no_difference 'Role.count' do
      delete role_path(role)
    end

    assert_redirected_to roles_path
  end

  test 'admin exports role definitions as a JSON attachment' do
    sign_in_as_admin
    role = Role.create!(name: 'Key fob manager', privileges: Privilege.where(key: 'access.manage_rfids'))
    TrainingTopicRole.create!(training_topic: @topic, role: role, member_source: 'trained_in')

    get export_roles_path

    assert_response :success
    assert_match 'attachment', response.headers['Content-Disposition']
    exported = response.parsed_body['roles'].find { |entry| entry['name'] == 'Key fob manager' }
    assert_equal ['access.manage_rfids'], exported['privileges']
    assert_equal [{ 'name' => @topic.name, 'member_source' => 'trained_in' }], exported['topics']
  end

  test 'members cannot export role definitions' do
    sign_in_as_member

    get export_roles_path

    assert_response :redirect
  end

  test 'admin imports pasted role definitions' do
    sign_in_as_admin

    assert_difference 'Role.count', 1 do
      post import_roles_path, params: { json: import_json, mode: 'replace', dry_run: '0' }
    end

    assert_redirected_to roles_path
    assert_equal ['access.manage_rfids'], Role.find_by!(name: 'Imported').privilege_keys
  end

  test 'admin imports an uploaded file' do
    sign_in_as_admin
    file = Rack::Test::UploadedFile.new(StringIO.new(import_json), 'application/json',
                                        original_filename: 'roles.json')

    assert_difference 'Role.count', 1 do
      post import_roles_path, params: { file: file, mode: 'replace', dry_run: '0' }
    end
  end

  test 'a dry run previews without saving' do
    sign_in_as_admin

    assert_no_difference 'Role.count' do
      post import_roles_path, params: { json: import_json, mode: 'replace', dry_run: '1' }
    end

    assert_response :success
    assert_match 'nothing was saved', response.body
  end

  test 'a bad document re-renders the form with the error' do
    sign_in_as_admin

    post import_roles_path, params: { json: '{ nope', dry_run: '0' }

    assert_response :unprocessable_content
    assert_match 'Could not parse JSON', response.body
  end

  test 'an import with skipped entries stays on the page to report them' do
    sign_in_as_admin
    json = { 'roles' => [{ 'name' => 'Imported', 'privileges' => ['nonsense.key'] }] }.to_json

    post import_roles_path, params: { json: json, dry_run: '0' }

    assert_response :success
    assert_match 'nonsense.key', response.body
    assert_predicate Role.find_by!(name: 'Imported').privilege_keys, :empty?
  end

  test 'members cannot import role definitions' do
    sign_in_as_member

    assert_no_difference 'Role.count' do
      post import_roles_path, params: { json: import_json, dry_run: '0' }
    end
  end

  test 'admin attaches a role to a topic with a conferral source' do
    sign_in_as_admin
    role = Role.create!(name: 'Curator', privileges: Privilege.where(key: 'training.topics.manage_links'))

    assert_difference 'TrainingTopicRole.count', 1 do
      post training_topic_topic_roles_path(@topic),
           params: { training_topic_role: { role_id: role.id, member_source: 'can_train' } }
    end

    assert_predicate TrainingTopicRole.find_by(training_topic: @topic, role: role), :can_train?
  end

  test 'the same role cannot be attached twice with the same source' do
    sign_in_as_admin
    role = Role.create!(name: 'Curator')
    TrainingTopicRole.create!(training_topic: @topic, role: role, member_source: 'can_train')

    assert_no_difference 'TrainingTopicRole.count' do
      post training_topic_topic_roles_path(@topic),
           params: { training_topic_role: { role_id: role.id, member_source: 'can_train' } }
    end
  end

  test 'admin detaches a role from a topic' do
    sign_in_as_admin
    role = Role.create!(name: 'Curator')
    topic_role = TrainingTopicRole.create!(training_topic: @topic, role: role, member_source: 'trained_in')

    assert_difference 'TrainingTopicRole.count', -1 do
      delete training_topic_topic_role_path(@topic, topic_role)
    end
  end

  test 'members cannot attach roles to topics' do
    sign_in_as_member
    role = Role.create!(name: 'Curator')

    assert_no_difference 'TrainingTopicRole.count' do
      post training_topic_topic_roles_path(@topic),
           params: { training_topic_role: { role_id: role.id, member_source: 'trained_in' } }
    end
  end

  test 'the topic page lists attached roles' do
    sign_in_as_admin
    role = Role.create!(name: 'Key fob manager', privileges: Privilege.where(key: 'access.manage_rfids'))
    TrainingTopicRole.create!(training_topic: @topic, role: role, member_source: 'trained_in')

    get edit_training_topic_path(@topic)

    assert_response :success
    assert_match 'Key fob manager', response.body
    assert_match 'Trained in topic', response.body
  end

  private

  def import_json
    {
      'format' => Roles::DefinitionExport::FORMAT,
      'roles' => [{ 'name' => 'Imported', 'privileges' => ['access.manage_rfids'],
                    'topics' => [{ 'name' => @topic.name, 'member_source' => 'trained_in' }] }]
    }.to_json
  end

  def sign_in_as_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: { session: { email: account.email, password: 'localpassword123' } }
  end

  def sign_in_as_member
    account = local_accounts(:regular_member)
    post local_login_path, params: { session: { email: account.email, password: 'memberpassword123' } }
  end
end
