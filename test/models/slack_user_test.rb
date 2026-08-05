require 'test_helper'

class SlackUserTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # The validation checks for a duplicate before writing, which two concurrent creates can
  # both pass. Encryption left the email column unable to catch what slips through, since the
  # same address encrypts differently every time, so the digest index has to.
  test 'the database refuses a second row holding the same address' do
    SlackUser.create!(slack_id: 'UFIRST', email: 'shared@example.com')
    duplicate = SlackUser.new(slack_id: 'USECOND', email: 'shared@example.com')
    duplicate.validate # fills in the digest the way a racing create would

    assert_raises ActiveRecord::RecordNotUnique do
      duplicate.save!(validate: false)
    end
  end

  test 'the database still allows many rows without an address' do
    SlackUser.create!(slack_id: 'UNONE1')
    SlackUser.create!(slack_id: 'UNONE2')

    assert_equal 2, SlackUser.where(slack_id: %w[UNONE1 UNONE2]).count
  end

  test 'display name falls back through fields' do
    user = SlackUser.new(slack_id: 'U123', display_name: '', real_name: '', username: 'tester')
    assert_equal 'tester', user.display_name
  end

  test 'with_attribute scope filters on json column' do
    slack_users(:with_dept)
    slack_users(:with_other_dept)

    results = SlackUser.with_attribute(:department, 'IT')
    assert_equal ['with_dept@example.com'], results.pluck(:email)
  end

  test 'active scope excludes inactive and deactivated accounts' do
    recent = SlackUser.create!(slack_id: 'URECENT', last_active_at: 1.month.ago)
    old = SlackUser.create!(slack_id: 'UOLD', last_active_at: 2.years.ago)
    unknown = SlackUser.create!(slack_id: 'UUNKNOWN', last_active_at: nil)
    deactivated = SlackUser.create!(slack_id: 'UDEACTIVATED', deleted: true, last_active_at: 1.month.ago)

    assert_includes SlackUser.active, recent
    assert_not_includes SlackUser.active, old
    assert_not_includes SlackUser.active, unknown
    assert_not_includes SlackUser.active, deactivated
  end

  test 'inactive scope includes accounts with no or old activity' do
    recent = SlackUser.create!(slack_id: 'URECENT2', last_active_at: 1.month.ago)
    old = SlackUser.create!(slack_id: 'UOLD2', last_active_at: 2.years.ago)
    unknown = SlackUser.create!(slack_id: 'UUNKNOWN2', last_active_at: nil)

    assert_not_includes SlackUser.inactive, recent
    assert_includes SlackUser.inactive, old
    assert_includes SlackUser.inactive, unknown
  end

  test 'linking a member enqueues Authentik user sync' do
    slack_user = slack_users(:with_dept)
    user = users(:two)

    assert_enqueued_with(job: Authentik::UserSyncJob, args: [user.id]) do
      slack_user.update!(user_id: user.id)
    end
  end

  test 'unlinking a member enqueues Authentik user sync for the previous member' do
    slack_user = slack_users(:with_dept)
    user = users(:two)
    slack_user.update!(user_id: user.id)

    assert_enqueued_with(job: Authentik::UserSyncJob, args: [user.id]) do
      slack_user.update!(user_id: nil)
    end
  end
end
