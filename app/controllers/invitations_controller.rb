class InvitationsController < AdminController
  def new
    @invitation = Invitation.new
    @expiry_hours = MembershipSetting.instance.invitation_expiry_hours
  end

  def create
    @invitation = Invitation.new(
      email: params[:invitation][:email]&.strip,
      invited_by: current_user
    )

    if @invitation.save
      enqueue_invitation_email(@invitation)
      redirect_to root_path, notice: "Invitation sent to #{@invitation.email}. It will expire in #{humanize_hours(MembershipSetting.instance.invitation_expiry_hours)}."
    else
      @expiry_hours = MembershipSetting.instance.invitation_expiry_hours
      render :new, status: :unprocessable_entity
    end
  end

  private

  def enqueue_invitation_email(invitation)
    template = EmailTemplate.find_enabled('member_invitation')
    org = ENV.fetch('ORGANIZATION_NAME', 'Member Manager')

    variables = {
      organization_name: org,
      date: Date.current.strftime('%B %d, %Y'),
      app_url: ENV.fetch('APP_BASE_URL', 'http://localhost:3000'),
      invitation_url: invitation.invitation_url,
      invitation_expiry: humanize_expiry(invitation.expires_at)
    }

    if template
      rendered = template.render(variables)
      mail = QueuedMail.create!(
        to: invitation.email,
        subject: rendered[:subject],
        body_html: rendered[:body_html],
        body_text: rendered[:body_text] || '',
        reason: "Membership invitation for #{invitation.email}",
        email_template: template,
        mailer_action: 'member_invitation',
        mailer_args: { invitation_id: invitation.id },
        status: 'approved'
      )
    else
      mail = QueuedMail.create!(
        to: invitation.email,
        subject: "#{org}: You're Invited to Join!",
        body_html: "<p>You've been invited to join #{org}.</p><p><a href=\"#{invitation.invitation_url}\">Click here to create your account</a></p><p>This invitation expires #{humanize_expiry(invitation.expires_at)}.</p>",
        body_text: "You've been invited to join #{org}.\n\nCreate your account: #{invitation.invitation_url}\n\nThis invitation expires #{humanize_expiry(invitation.expires_at)}.",
        reason: "Membership invitation for #{invitation.email}",
        mailer_action: 'member_invitation',
        mailer_args: { invitation_id: invitation.id },
        status: 'approved'
      )
    end

    MailLogEntry.log!(mail, 'created', details: "Queued invitation to #{invitation.email}")
    QueuedMailDeliveryJob.perform_later(mail.id)
  end

  def humanize_expiry(time)
    distance = time - Time.current
    if distance > 1.day
      "in #{(distance / 1.day).round} days"
    elsif distance > 1.hour
      "in #{(distance / 1.hour).round} hours"
    else
      "in #{(distance / 1.minute).round} minutes"
    end
  end

  def humanize_hours(hours)
    if hours >= 24 && (hours % 24).zero?
      "#{hours / 24} #{'day'.pluralize(hours / 24)}"
    else
      "#{hours} #{'hour'.pluralize(hours)}"
    end
  end
end
