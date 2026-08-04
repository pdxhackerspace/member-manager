# Seeds the privilege catalog and starter roles, then attaches the application roles to the
# existing director topics so the Executive Director gate keeps behaving as it did before.
# Topic names are spelled out here rather than referenced from a constant because migrations
# must keep working after the application stops hard-coding them.
class SeedPrivilegesAndDirectorRoles < ActiveRecord::Migration[8.1]
  DIRECTOR_TOPIC_ROLES = {
    'Executive Director' => 'Application approver',
    'Associate Executive Director' => 'Application reviewer',
    'Assistant Executive Director' => 'Application reviewer'
  }.freeze

  def up
    Privilege.seed_defaults!
    Role.seed_defaults!

    DIRECTOR_TOPIC_ROLES.each do |topic_name, role_name|
      topic = TrainingTopic.where('LOWER(name) = ?', topic_name.downcase).first
      role = Role.find_by(name: role_name)
      next if topic.nil? || role.nil?

      TrainingTopicRole.find_or_create_by!(training_topic: topic, role: role, member_source: 'trained_in')
    end
  end

  def down
    DIRECTOR_TOPIC_ROLES.each do |topic_name, role_name|
      topic = TrainingTopic.where('LOWER(name) = ?', topic_name.downcase).first
      role = Role.find_by(name: role_name)
      next if topic.nil? || role.nil?

      TrainingTopicRole.where(training_topic: topic, role: role, member_source: 'trained_in').destroy_all
    end

    Role.where(name: Role::DEFAULT_ROLES.map { |attrs| attrs[:name] }).destroy_all
    Privilege.where(key: Privilege::CATALOG.map { |attrs| attrs[:key] }).destroy_all
  end
end
