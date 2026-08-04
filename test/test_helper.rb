ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Privileges only ever reach a member through a role attached to a topic they hold, so tests
    # that need one have to build that chain. Returns the conferring topic.
    def grant_privileges(user, *privilege_keys, member_source: 'trained_in', topic: nil)
      suffix = "#{user.id}-#{SecureRandom.hex(4)}"
      topic ||= TrainingTopic.create!(name: "Privilege topic #{suffix}", offered_to_members: false)
      role = Role.create!(name: "Privilege role #{suffix}",
                          privileges: privilege_keys.map { |key| find_or_create_privilege(key) })
      TrainingTopicRole.create!(training_topic: topic, role: role, member_source: member_source)

      if member_source == 'can_train'
        TrainerCapability.find_or_create_by!(user: user, training_topic: topic)
      else
        Training.create!(trainee: user, training_topic: topic, trained_at: Time.current)
      end

      user.reset_privilege_cache!
      topic
    end

    # Swaps Authentik::Client for a stand-in. Reading the constant first matters: Zeitwerk
    # leaves it as a pending autoload, and remove_const on a pending autoload returns nil,
    # so the restore would pin Authentik::Client to nil for the rest of the worker process.
    def with_stubbed_authentik_client(replacement)
      original = Authentik::Client
      Authentik.send(:remove_const, :Client)
      Authentik.const_set(:Client, replacement)

      begin
        yield
      ensure
        Authentik.send(:remove_const, :Client)
        Authentik.const_set(:Client, original)
      end
    end

    def find_or_create_privilege(key)
      Privilege.find_by(key: key.to_s) || Privilege.create!(
        Privilege::CATALOG.find { |entry| entry[:key] == key.to_s } || { key: key.to_s, label: key.to_s }
      )
    end
  end
end
