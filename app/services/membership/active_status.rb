module Membership
  # Single source of truth for whether a member's `active` column should be true.
  # User#compute_active_status delegates here on every save; rake reconciliation uses
  # the same logic so the column stays aligned with membership state.
  #
  # Priority (first match wins):
  #   1. Banned or deceased -> inactive
  #   2. Sponsored -> active
  #   3. Emergency active override -> active
  #   4. Guest with unexpired limited access -> active
  #   5. Paying/cancelled/unknown with current dues -> active; lapsed/overdue -> inactive
  class ActiveStatus
    def self.compute(user)
      return user.active if user.service_account?

      return false if user.membership_status.in?(%w[banned deceased])
      return true if sponsored?(user)
      return true if user.emergency_active_override?

      case user.membership_status
      when 'guest'
        !user.limited_guest_or_sponsored_access_expired?
      when 'paying', 'cancelled', 'unknown'
        user.dues_status == 'current'
      else
        false
      end
    end

    def self.sponsored?(user)
      user.is_sponsored? || user.membership_status == 'sponsored' || user.payment_type == 'sponsored'
    end

    def self.apply_to(user)
      return if user.service_account?

      user.active = compute(user)
      user.payment_type = 'inactive' if user.deceased?
    end

    def self.needs_reconciliation?(user)
      return false if user.service_account?

      user.active != compute(user) || (user.deceased? && user.payment_type != 'inactive')
    end

    def self.reconcile!(user)
      return false unless needs_reconciliation?(user)

      apply_to(user)
      user.save!
      true
    end

    def self.assign_and_save!(user, attrs)
      attrs.each { |key, value| user.public_send(:"#{key}=", value) }
      user.save!
    end
  end
end
