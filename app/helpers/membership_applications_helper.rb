module MembershipApplicationsHelper
  def membership_application_applicant_status_path(application)
    verification = application.status_page_verification
    apply_application_status_path(token: verification.token) if verification
  end
end
