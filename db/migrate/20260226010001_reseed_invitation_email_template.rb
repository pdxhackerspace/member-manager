class ReseedInvitationEmailTemplate < ActiveRecord::Migration[8.1]
  def up
    template = EmailTemplate.find_by(key: 'member_invitation')
    if template
      attrs = EmailTemplate::DEFAULT_TEMPLATES['member_invitation']
      template.update!(
        subject: attrs[:subject],
        body_html: attrs[:body_html],
        body_text: attrs[:body_text],
        description: attrs[:description]
      )
    else
      EmailTemplate.seed_defaults!
    end
  end

  def down
  end
end
