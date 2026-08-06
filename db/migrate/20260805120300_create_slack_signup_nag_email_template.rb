class CreateSlackSignupNagEmailTemplate < ActiveRecord::Migration[8.1]
  def up
    return if EmailTemplate.exists?(key: 'slack_signup_nag')

    attrs = EmailTemplate::DEFAULT_TEMPLATES.fetch('slack_signup_nag')
    EmailTemplate.create!(
      attrs.merge(
        key: 'slack_signup_nag',
        enabled: true,
        needs_review: true,
        send_immediately: true
      )
    )
  end

  def down
    EmailTemplate.where(key: 'slack_signup_nag').destroy_all
  end
end
