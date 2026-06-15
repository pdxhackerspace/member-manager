module InitiatedApplicationActions
  extend ActiveSupport::Concern

  def extend_initiated_application
    verification = ApplicationVerification.find(params[:id])
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

    if verification.verified?
      redirect_to_initiated_applications alert: 'This application is already open; no confirmation email is needed.'
      return
    end

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
end
