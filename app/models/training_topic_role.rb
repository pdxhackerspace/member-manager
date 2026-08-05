# Attaches a role to a training topic and records which population it is conferred to.
# The member_source vocabulary matches ApplicationGroup: members with a Training record
# for the topic ('trained_in') or members who can train it ('can_train').
class TrainingTopicRole < ApplicationRecord
  MEMBER_SOURCES = %w[trained_in can_train].freeze

  belongs_to :training_topic
  belongs_to :role

  validates :member_source, presence: true, inclusion: { in: MEMBER_SOURCES }
  validates :role_id, uniqueness: { scope: %i[training_topic_id member_source] }

  scope :trained_in, -> { where(member_source: 'trained_in') }
  scope :can_train, -> { where(member_source: 'can_train') }

  MEMBER_SOURCES.each do |source|
    define_method(:"#{source}?") { member_source == source }
  end

  def member_source_label
    trained_in? ? 'Trained in topic' : 'Can train topic'
  end
end
