require 'test_helper'

class UserInterestTest < ActiveSupport::TestCase
  test 'valid with user and interest' do
    ui = UserInterest.new(user: users(:one), interest: interests(:woodworking))
    assert_predicate ui, :valid?
  end

  test 'invalid without a user' do
    ui = UserInterest.new(interest: interests(:electronics))
    assert_not ui.valid?
    assert_includes ui.errors[:user], 'must exist'
  end

  test 'invalid without an interest' do
    ui = UserInterest.new(user: users(:one))
    assert_not ui.valid?
    assert_includes ui.errors[:interest], 'must exist'
  end

  test 'each user-interest pair is unique' do
    # users(:one) already has electronics via fixture
    duplicate = UserInterest.new(user: users(:one), interest: interests(:electronics))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:interest_id], 'has already been taken'
  end

  test 'same interest can belong to multiple users' do
    # electronics is already linked to users(:one) and users(:two)
    assert_equal 2, interests(:electronics).user_interests.count
  end

  test 'user can have multiple interests' do
    # users(:one) has electronics and programming
    assert_equal 2, users(:one).user_interests.count
  end
end
