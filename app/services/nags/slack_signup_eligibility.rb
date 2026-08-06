module Nags
  class SlackSignupEligibility
    APPROVAL_ANCHOR_SQL = <<~SQL.squish
      COALESCE(
        (SELECT MAX(membership_applications.reviewed_at)
         FROM membership_applications
         WHERE membership_applications.user_id = users.id
           AND membership_applications.status = 'approved'),
        users.created_at
      )
    SQL

    def self.due(now: Time.current)
      initial_cutoff = now - MembershipSetting.slack_signup_nag_initial_delay_days.days
      repeat_cutoff = now - MembershipSetting.slack_signup_nag_repeat_delay_days.days

      base_scope
        .where("#{APPROVAL_ANCHOR_SQL} <= ?", initial_cutoff)
        .where('slack_signup_nag_sent_at IS NULL OR slack_signup_nag_sent_at <= ?', repeat_cutoff)
        .order(:full_name)
    end

    def self.count_due(now: Time.current)
      due(now: now).count
    end

    def self.total_without_slack
      base_scope.count
    end

    def self.due?(user, now: Time.current)
      return false unless base_user?(user)

      initial_cutoff = now - MembershipSetting.slack_signup_nag_initial_delay_days.days
      repeat_cutoff = now - MembershipSetting.slack_signup_nag_repeat_delay_days.days
      anchor = user.membership_approved_at

      anchor <= initial_cutoff &&
        (user.slack_signup_nag_sent_at.nil? || user.slack_signup_nag_sent_at <= repeat_cutoff)
    end

    DELIVERABLE_EMAIL_SQL = "BTRIM(COALESCE(users.email, '')) <> ''".freeze

    def self.base_scope
      User.where(active: true)
          .non_service_accounts
          .where.missing(:slack_user)
          .where(slack_id: [nil, ''])
          .where(slack_handle: [nil, ''])
          .where(DELIVERABLE_EMAIL_SQL)
    end

    def self.base_user?(user)
      user.active? &&
        !user.service_account? &&
        lacks_slack_identity?(user) &&
        user.email.present?
    end

    def self.lacks_slack_identity?(user)
      user.slack_user.blank? && user.slack_id.blank? && user.slack_handle.blank?
    end

    private_class_method :base_scope, :base_user?, :lacks_slack_identity?
  end
end
