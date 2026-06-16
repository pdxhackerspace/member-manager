module InitiatedApplicationActions
  extend ActiveSupport::Concern

  def extend_initiated_application
    verification = ApplicationVerification.find(params[:id])
    return if reject_initiated_action_when_application_received!(verification)

    duration = initiated_application_extension_duration

    if duration.nil?
      redirect_to_initiated_applications alert: 'Choose one day or one week.'
      return
    end

    verification.extend_expiration_by!(duration)
    redirect_to_initiated_applications notice: "Extended #{verification.email}'s verification link."
  end

  def resend_initiated_application
    verification = ApplicationVerification.find(params[:id])
    return if reject_initiated_action_when_application_received!(verification)

    verification.deliver_verification_email!
    redirect_to_initiated_applications notice: "Re-sent the confirmation link to #{verification.email}."
  end

  private

  def redirect_to_initiated_applications(flash)
    redirect_to membership_applications_path(status: 'initiated'), flash
  end

  def initiated_application_extension_duration
    case params[:duration]
    when 'day' then 1.day
    when 'week' then 1.week
    end
  end

  def reject_initiated_action_when_application_received!(verification)
    return false if verification.awaiting_application?

    redirect_to_initiated_applications alert: 'An application has already been received for this email.'
    true
  end
end
