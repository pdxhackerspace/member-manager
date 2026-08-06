class UpdateSlackSignupNagEmailTemplate < ActiveRecord::Migration[8.1]
  def up
    template = EmailTemplate.find_by(key: 'slack_signup_nag')
    return unless template

    attrs = EmailTemplate::DEFAULT_TEMPLATES.fetch('slack_signup_nag')
    template.update!(
      body_html: attrs[:body_html],
      body_text: attrs[:body_text]
    )
  end

  def down
    # Body copy only; leave the template in place.
  end
end
