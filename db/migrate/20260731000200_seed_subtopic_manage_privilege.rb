class SeedSubtopicManagePrivilege < ActiveRecord::Migration[8.1]
  PRIVILEGE_KEY = 'training.subtopics.manage'.freeze

  def up
    Privilege.seed_defaults!
    Role.seed_defaults!

    # Role.seed_defaults! leaves existing roles alone so admin edits survive, so an Area lead
    # created by the previous migration needs the new privilege added explicitly.
    role = Role.find_by(name: 'Area lead')
    privilege = Privilege.find_by(key: PRIVILEGE_KEY)
    return if role.nil? || privilege.nil?

    role.privileges << privilege unless role.privileges.exists?(privilege.id)
  end

  def down
    Privilege.where(key: PRIVILEGE_KEY).destroy_all
  end
end
