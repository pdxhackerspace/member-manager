class Message < ApplicationRecord
  belongs_to :sender, class_name: 'User'
  belongs_to :recipient, class_name: 'User'

  validates :subject, presence: true
  validates :body, presence: true

  scope :newest_first, -> { order(created_at: :desc) }
  scope :unread, -> { where(read_at: nil) }
  scope :for_user, ->(user) { where(recipient: user) }

  def unread?
    read_at.nil?
  end

  def read!
    update!(read_at: Time.current) if read_at.nil?
  end
end
