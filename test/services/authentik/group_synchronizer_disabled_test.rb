require 'test_helper'

module Authentik
  class GroupSynchronizerDisabledTest < ActiveSupport::TestCase
    test 'returns 0 and skips sync when authentik source is disabled' do
      member_sources(:authentik).update!(enabled: false)

      result = GroupSynchronizer.new.call

      assert_equal 0, result
    end
  end
end
