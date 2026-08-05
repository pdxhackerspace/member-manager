# Authorization for the application admin surface. Reaching any of it requires
# applications.view; each verb then carries its own privilege, so a reviewer can vote and
# record tours without being able to approve.
module MembershipApplicationPrivileges
  extend ActiveSupport::Concern

  ADMIN_ACTIONS = %i[
    index show import approve reject delay_for_review mark_needs_review link_user unlink_user vote_ai_feedback
    save_tour_feedback vote_acceptance extend_initiated_application resend_initiated_application
  ].freeze

  APPLICATION_MEMBER_ACTIONS = %i[
    show approve reject delay_for_review mark_needs_review link_user unlink_user vote_ai_feedback
    save_tour_feedback vote_acceptance
  ].freeze

  ACTION_PRIVILEGES = {
    import: :'applications.import',
    approve: :'applications.approve',
    reject: :'applications.reject',
    delay_for_review: :'applications.park_review',
    mark_needs_review: :'applications.park_review',
    link_user: :'applications.link_member',
    unlink_user: :'applications.link_member',
    vote_ai_feedback: :'applications.review',
    save_tour_feedback: :'applications.review',
    vote_acceptance: :'applications.review',
    extend_initiated_application: :'applications.manage_initiated',
    resend_initiated_application: :'applications.manage_initiated'
  }.freeze

  included do
    before_action -> { require_privilege!(:'applications.view') }, only: ADMIN_ACTIONS
    before_action :set_application_admin, only: APPLICATION_MEMBER_ACTIONS
    before_action :require_action_privilege!, only: ACTION_PRIVILEGES.keys
  end

  private

  def require_action_privilege!
    privilege = ACTION_PRIVILEGES[action_name.to_sym]
    return if privilege.nil? || can?(privilege)

    alert = 'You do not have permission to do that with applications.'
    if @application
      redirect_to membership_application_path(@application), alert: alert
    else
      redirect_to membership_applications_path, alert: alert
    end
  end
end
