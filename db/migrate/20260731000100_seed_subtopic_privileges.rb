class SeedSubtopicPrivileges < ActiveRecord::Migration[8.1]
  NEW_PRIVILEGE_KEYS = %w[training.topics.edit_details training.subtopics.create].freeze

  def up
    Privilege.seed_defaults!
    Role.seed_defaults!
  end

  def down
    Privilege.where(key: NEW_PRIVILEGE_KEYS).destroy_all
    Role.where(name: 'Area lead').destroy_all
  end
end
