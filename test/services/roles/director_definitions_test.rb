require 'test_helper'

module Roles
  # Guards the shipped payload at db/role_definitions/director_roles.json. Its job is to leave the
  # three director training topics conferring what they conferred before roles existed, so these
  # tests assert the pre-roles behaviour rather than the literal contents of the file.
  class DirectorDefinitionsTest < ActiveSupport::TestCase
    PAYLOAD_PATH = Rails.root.join('db/role_definitions/director_roles.json')

    DIRECTOR_TOPICS = ['Executive Director', 'Associate Executive Director',
                       'Assistant Executive Director'].freeze

    setup do
      Privilege.seed_defaults!
      @topics = DIRECTOR_TOPICS.index_with { |name| TrainingTopic.create!(name: name, offered_to_members: false) }
    end

    test 'every privilege the payload names exists in the catalog' do
      keys = payload['roles'].flat_map { |role| role['privileges'] }.uniq

      assert_equal [], keys - Privilege::CATALOG.pluck(:key)
    end

    test 'importing the payload attaches a role to each director topic' do
      result = import!

      assert_equal 3, result.roles_created
      assert_equal 3, result.attachments_created
      @topics.each_value do |topic|
        assert_predicate topic.topic_roles.reload, :any?, "#{topic.name} confers nothing"
      end
    end

    test 'the payload applies without warnings when the director topics exist' do
      assert_empty import!.warnings
    end

    # Before roles, an Executive Director training record was what allowed the final decision.
    test 'an executive director can approve, reject, and park applications' do
      import!
      director = trained_director('Executive Director')

      assert director.can?(:'applications.approve')
      assert director.can?(:'applications.reject')
      assert director.can?(:'applications.park_review')
      assert_predicate director, :can_finalize_membership_application?
    end

    # The old masking rule keyed on Executive Director training alone, so the deputy offices
    # deliberately do not carry applications.view_pii.
    test 'only the executive director sees applicant contact details unmasked' do
      import!

      assert trained_director('Executive Director').can?(:'applications.view_pii')
      assert_not trained_director('Associate Executive Director').can?(:'applications.view_pii')
      assert_not trained_director('Assistant Executive Director').can?(:'applications.view_pii')
    end

    test 'the deputy offices review without being able to finalize' do
      import!

      ['Associate Executive Director', 'Assistant Executive Director'].each do |topic_name|
        director = trained_director(topic_name)

        assert director.can?(:'applications.review'), "#{topic_name} cannot review"
        assert director.can?(:'applications.view'), "#{topic_name} cannot reach the queue"
        assert_not director.can?(:'applications.approve'), "#{topic_name} can approve"
        assert_not_predicate director, :can_finalize_membership_application?
      end
    end

    # All three offices were on the pre-roles notification list, which now resolves through
    # applications.review.
    test 'all three offices receive director notifications' do
      import!
      directors = DIRECTOR_TOPICS.map { |topic_name| trained_director(topic_name) }

      notified = User.with_privilege('applications.review')

      directors.each { |director| assert_includes notified, director }
    end

    test 'holding a director topic confers nothing outside the office' do
      import!
      director = trained_director('Executive Director')

      assert_not director.can?(:'members.delete')
      assert_not director.can?(:'members.grant_admin')
      assert_not director.can?(:'settings.applications')
    end

    test 'the payload is idempotent' do
      import!

      assert_not_predicate import!, :changed?
    end

    private

    def payload
      @payload ||= JSON.parse(File.read(PAYLOAD_PATH))
    end

    def import!
      result = DefinitionImport.call(File.read(PAYLOAD_PATH), mode: 'replace')
      assert_predicate result, :success?
      result
    end

    def trained_director(topic_name)
      user = User.create!(email: "#{topic_name.parameterize}@example.com", full_name: topic_name)
      Training.create!(trainee: user, training_topic: @topics.fetch(topic_name), trained_at: Time.current)
      user
    end
  end
end
