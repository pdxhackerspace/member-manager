# A reusable bundle of privileges. Roles are attached to training topics rather than
# to individual members: holding a topic confers that topic's roles.
class Role < ApplicationRecord
  has_many :role_privileges, dependent: :destroy
  has_many :privileges, through: :role_privileges
  has_many :topic_roles, class_name: 'TrainingTopicRole', dependent: :destroy
  has_many :training_topics, through: :topic_roles

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :ordered, -> { order(:name) }

  # Starter bundles. Seeding only fills in privileges for roles that do not exist yet,
  # so an admin's later edits to a role are never overwritten.
  DEFAULT_ROLES = [
    {
      name: 'Front desk',
      description: 'Greeters who need to identify members and watch the application queue.',
      privileges: %w[members.view_list members.view_profile applications.view invitations.create]
    },
    {
      name: 'Application reviewer',
      description: 'Reviews applications, records tours, and votes, without making the final decision.',
      privileges: %w[applications.view applications.view_pii applications.review applications.link_member
                     training.grant_trainer]
    },
    {
      name: 'Application approver',
      description: 'Reviews applications and makes the final approve or reject decision.',
      privileges: %w[applications.view applications.view_pii applications.review applications.link_member
                     applications.approve applications.reject applications.park_review
                     applications.manage_initiated training.grant_trainer]
    },
    {
      name: 'Key fob manager',
      description: 'Issues and revokes key fobs and pauses building access.',
      privileges: %w[access.view_rfids access.manage_rfids access.pause_resume]
    },
    {
      name: 'Billing coordinator',
      description: 'Reconciles dues and payments.',
      privileges: %w[plans.view_hidden plans.manual_payments payments.view payments.link members.edit_membership]
    },
    {
      name: 'Topic curator',
      description: 'Curates resources and documents for a topic. Attach with the "can train" source.',
      privileges: %w[training.topics.manage_links training.documents.manage training.topics.edit_details]
    },
    {
      name: 'Area lead',
      description: 'Curates a topic and the subtopics under it, and trains on all of them. ' \
                   'Attach with the "can train" source.',
      privileges: %w[training.topics.manage_links training.documents.manage training.topics.edit_details
                     training.subtopics.create training.record training.revoke training.respond_requests]
    },
    {
      name: 'Communications editor',
      description: 'Maintains email templates and the outgoing mail queue.',
      privileges: %w[email_templates.view email_templates.edit queued_mail.view queued_mail.approve
                     text_fragments.manage]
    }
  ].freeze

  def self.seed_defaults!
    DEFAULT_ROLES.each do |attrs|
      role = find_or_initialize_by(name: attrs[:name])
      next unless role.new_record?

      role.description = attrs[:description]
      role.privileges = Privilege.where(key: attrs[:privileges])
      role.save!
    end
  end

  def privilege_keys
    privileges.map(&:key)
  end
end
