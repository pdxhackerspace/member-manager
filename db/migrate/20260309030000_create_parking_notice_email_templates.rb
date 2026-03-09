class CreateParkingNoticeEmailTemplates < ActiveRecord::Migration[8.1]
  def up
    templates = [
      {
        key: 'parking_permit_issued',
        name: 'Parking Permit Issued',
        description: 'Sent to a member when a parking permit is created for their project.',
        subject: '{{organization_name}}: Parking Permit Issued',
        body_html: <<~HTML,
          <p>Hi {{member_name}},</p>
          <p>A parking permit has been issued for your project at <strong>{{location}}</strong>.</p>
          <p><strong>Description:</strong> {{description}}</p>
          <p><strong>Expires:</strong> {{expires_at}}</p>
          <p>Please make sure to remove or renew your project before the permit expires.</p>
        HTML
        body_text: <<~TEXT
          Hi {{member_name}},

          A parking permit has been issued for your project at {{location}}.

          Description: {{description}}
          Expires: {{expires_at}}

          Please make sure to remove or renew your project before the permit expires.
        TEXT
      },
      {
        key: 'parking_ticket_issued',
        name: 'Parking Ticket Issued',
        description: 'Sent to a member when a parking ticket is created for their project.',
        subject: '{{organization_name}}: Parking Ticket — Project Needs Attention',
        body_html: <<~HTML,
          <p>Hi {{member_name}},</p>
          <p>A parking ticket has been issued for a project at <strong>{{location}}</strong> that has been attributed to you.</p>
          <p><strong>Description:</strong> {{description}}</p>
          <p><strong>Deadline:</strong> {{expires_at}}</p>
          <p>Please remove or address the project before the deadline.</p>
        HTML
        body_text: <<~TEXT
          Hi {{member_name}},

          A parking ticket has been issued for a project at {{location}} that has been attributed to you.

          Description: {{description}}
          Deadline: {{expires_at}}

          Please remove or address the project before the deadline.
        TEXT
      },
      {
        key: 'parking_permit_expired',
        name: 'Parking Permit Expired',
        description: 'Sent to a member when their parking permit expires.',
        subject: '{{organization_name}}: Your Parking Permit Has Expired',
        body_html: <<~HTML,
          <p>Hi {{member_name}},</p>
          <p>Your parking permit for the project at <strong>{{location}}</strong> has expired.</p>
          <p><strong>Description:</strong> {{description}}</p>
          <p>Please remove your project from the space as soon as possible, or contact an admin to request an extension.</p>
        HTML
        body_text: <<~TEXT
          Hi {{member_name}},

          Your parking permit for the project at {{location}} has expired.

          Description: {{description}}

          Please remove your project from the space as soon as possible, or contact an admin to request an extension.
        TEXT
      },
      {
        key: 'parking_ticket_expired',
        name: 'Parking Ticket Expired',
        description: 'Sent to a member when a parking ticket deadline passes.',
        subject: '{{organization_name}}: Parking Ticket Deadline Passed',
        body_html: <<~HTML,
          <p>Hi {{member_name}},</p>
          <p>The deadline for the parking ticket at <strong>{{location}}</strong> has passed.</p>
          <p><strong>Description:</strong> {{description}}</p>
          <p>Please remove or address the project immediately.</p>
        HTML
        body_text: <<~TEXT
          Hi {{member_name}},

          The deadline for the parking ticket at {{location}} has passed.

          Description: {{description}}

          Please remove or address the project immediately.
        TEXT
      }
    ]

    templates.each do |attrs|
      EmailTemplate.create!(attrs.merge(enabled: true, needs_review: true))
    end
  end

  def down
    EmailTemplate.where(
      key: %w[parking_permit_issued parking_ticket_issued parking_permit_expired parking_ticket_expired]
    ).destroy_all
  end
end
