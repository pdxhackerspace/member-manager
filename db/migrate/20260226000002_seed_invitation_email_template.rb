class SeedInvitationEmailTemplate < ActiveRecord::Migration[8.1]
  def up
    EmailTemplate.seed_defaults!
  end

  def down
  end
end
