class Room < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  scope :ordered, -> { order(:position, :name) }

  def to_s
    name
  end
end
