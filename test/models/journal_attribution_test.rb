require 'test_helper'

# Journals name the human who acted. While impersonating that is the administrator, not the
# member being viewed as — otherwise the trail reads as though the member edited their own
# record. The account they were acting as is recorded alongside.
class JournalAttributionTest < ActiveSupport::TestCase
  setup do
    @admin = users(:two).tap { |user| user.update!(is_admin: true) }
    @member = users(:one)
  end

  teardown do
    Current.reset
  end

  test 'names the signed-in account when nobody is impersonating' do
    Current.user = @admin
    Current.true_user = @admin

    @member.update!(full_name: 'Renamed Once')

    assert_equal @admin, latest_journal_for(@member).actor_user
  end

  test 'names the administrator rather than the member being viewed as' do
    Current.user = @member
    Current.true_user = @admin

    @member.update!(full_name: 'Renamed While Impersonating')

    assert_equal @admin, latest_journal_for(@member).actor_user
  end

  test 'records which account was being acted as' do
    Current.user = @member
    Current.true_user = @admin

    @member.update!(full_name: 'Renamed While Impersonating')

    journal = latest_journal_for(@member)
    assert_predicate journal, :recorded_while_impersonating?
    assert_equal @member.display_name, journal.acting_as_name
  end

  test 'says nothing about impersonation when there was none' do
    Current.user = @admin
    Current.true_user = @admin

    @member.update!(full_name: 'Renamed Plainly')

    assert_not_predicate latest_journal_for(@member), :recorded_while_impersonating?
  end

  test 'system writes with no session are still unattributed' do
    Current.user = nil
    Current.true_user = nil

    @member.update!(full_name: 'Renamed By A Job')

    journal = latest_journal_for(@member)
    assert_nil journal.actor_user
    assert_not_predicate journal, :recorded_while_impersonating?
  end

  private

  def latest_journal_for(user)
    Journal.where(user: user).order(:created_at, :id).last
  end
end
