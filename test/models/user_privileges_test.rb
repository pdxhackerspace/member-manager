require 'test_helper'

class UserPrivilegesTest < ActiveSupport::TestCase
  setup do
    @member = users(:one)
    @topic = training_topics(:laser_cutting)
    @other_topic = training_topics(:woodworking)

    @global_privilege = Privilege.create!(key: 'test.global', label: 'Test global', privilege_scope: 'global')
    @topic_privilege = Privilege.create!(key: 'test.topic', label: 'Test topic', privilege_scope: 'topic')
    @role = Role.create!(name: 'Test role', privileges: [@global_privilege, @topic_privilege])
  end

  test 'members hold no privileges without a conferring topic' do
    assert_not @member.can?('test.global')
    assert_not @member.can?('test.topic', topic: @topic)
  end

  test 'admins hold every privilege' do
    admin = users(:two)
    admin.update!(is_admin: true)

    assert admin.can?('test.global')
    assert admin.can?('test.topic', topic: @topic)
    assert admin.can?('anything.at.all')
  end

  test 'training confers a topic trained_in roles' do
    attach_role(member_source: 'trained_in')
    train(@member, @topic)

    assert @member.can?('test.global')
    assert @member.can?('test.topic', topic: @topic)
  end

  test 'trainer capability does not confer trained_in roles' do
    attach_role(member_source: 'trained_in')
    TrainerCapability.create!(user: @member, training_topic: @topic)
    @member.reset_privilege_cache!

    assert_not @member.can?('test.global')
  end

  test 'trainer capability confers can_train roles' do
    attach_role(member_source: 'can_train')
    TrainerCapability.create!(user: @member, training_topic: @topic)
    @member.reset_privilege_cache!

    assert @member.can?('test.global')
    assert @member.can?('test.topic', topic: @topic)
  end

  test 'training does not confer can_train roles' do
    attach_role(member_source: 'can_train')
    train(@member, @topic)

    assert_not @member.can?('test.global')
  end

  test 'topic scoped privileges apply only to the conferring topic' do
    attach_role(member_source: 'trained_in')
    train(@member, @topic)
    train(@member, @other_topic)

    assert @member.can?('test.topic', topic: @topic)
    assert_not @member.can?('test.topic', topic: @other_topic)
  end

  test 'topic scoped privileges require a topic argument' do
    attach_role(member_source: 'trained_in')
    train(@member, @topic)

    assert_not @member.can?('test.topic')
  end

  test 'global privileges are additive across topics' do
    other_privilege = Privilege.create!(key: 'test.other', label: 'Other', privilege_scope: 'global')
    other_role = Role.create!(name: 'Other role', privileges: [other_privilege])
    attach_role(member_source: 'trained_in')
    TrainingTopicRole.create!(training_topic: @other_topic, role: other_role, member_source: 'trained_in')
    train(@member, @topic)
    train(@member, @other_topic)

    assert @member.can?('test.global')
    assert @member.can?('test.other')
  end

  test 'may_confer? blocks conferring global privileges the actor lacks' do
    attach_role(member_source: 'trained_in')

    assert_not @member.may_confer?(@topic, member_sources: ['trained_in'])
  end

  test 'may_confer? allows conferring global privileges the actor holds' do
    attach_role(member_source: 'trained_in')
    train(@member, @topic)

    assert @member.may_confer?(@topic, member_sources: ['trained_in'])
  end

  test 'may_confer? ignores topic scoped privileges' do
    topic_only_role = Role.create!(name: 'Topic only', privileges: [@topic_privilege])
    TrainingTopicRole.create!(training_topic: @other_topic, role: topic_only_role, member_source: 'can_train')

    assert @member.may_confer?(@other_topic, member_sources: %w[trained_in can_train])
  end

  test 'may_confer? always allows admins' do
    admin = users(:two)
    admin.update!(is_admin: true)
    attach_role(member_source: 'trained_in')

    assert admin.may_confer?(@topic, member_sources: ['trained_in'])
  end

  test 'may_confer? passes for topics carrying no roles' do
    assert @member.may_confer?(@topic, member_sources: TrainingTopicRole::MEMBER_SOURCES)
  end

  test 'with_privilege finds role holders and excludes admins' do
    admin = users(:two)
    admin.update!(is_admin: true)
    attach_role(member_source: 'trained_in')
    train(@member, @topic)

    holders = User.with_privilege('test.global')

    assert_includes holders, @member
    assert_not_includes holders, admin
  end

  test 'with_privilege finds trainers for can_train attachments' do
    attach_role(member_source: 'can_train')
    TrainerCapability.create!(user: @member, training_topic: @topic)

    assert_includes User.with_privilege('test.global'), @member
  end

  test 'topic reports the global privileges it confers' do
    attach_role(member_source: 'trained_in')

    assert_equal ['test.global'], @topic.conferred_global_privilege_keys(member_sources: ['trained_in'])
    assert_empty @topic.conferred_global_privilege_keys(member_sources: ['can_train'])
  end

  test 'privilege_bearing? reflects attached roles' do
    assert_not @topic.privilege_bearing?

    attach_role(member_source: 'trained_in')

    assert_predicate @topic.reload, :privilege_bearing?
  end

  private

  def attach_role(member_source:, topic: @topic, role: @role)
    TrainingTopicRole.create!(training_topic: topic, role: role, member_source: member_source)
  end

  def train(user, topic)
    Training.create!(trainee: user, training_topic: topic, trained_at: Time.current)
    user.reset_privilege_cache!
  end
end
