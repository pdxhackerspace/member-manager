require 'test_helper'

class RagControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  # This endpoint used to answer anyone. It exposed unmoderated member-submitted interests
  # and every training topic, including the internal ones that carry privileges.
  test 'requires authentication' do
    get '/rag.json'

    assert_redirected_to login_path
  end

  test 'answers a signed-in member' do
    sign_in_as_plain_member

    get '/rag.json'

    assert_response :success
    assert_equal 'application/json; charset=utf-8', response.content_type
  end

  test 'omits interests still awaiting review' do
    sign_in_as_plain_member
    pending = Interest.create!(name: 'Unmoderated Suggestion', needs_review: true)

    get '/rag.json'

    assert_not_includes response.parsed_body['interests'], pending.name
    assert_includes response.parsed_body['interests'], interests(:electronics).name
  end

  test 'omits topics not offered to members' do
    sign_in_as_plain_member

    get '/rag.json'

    topics = response.parsed_body['training_topics']
    assert_not_includes topics, training_topics(:electronics).name
    assert_includes topics, training_topics(:laser_cutting).name
  end

  test 'returns interests and training topics as sorted plain strings' do
    sign_in_as_plain_member

    get '/rag.json'

    body = response.parsed_body
    assert_equal %w[interests training_topics], body.keys.sort
    assert_equal body['interests'], body['interests'].sort
    assert_equal body['training_topics'], body['training_topics'].sort
    (body['interests'] + body['training_topics']).each { |value| assert_kind_of String, value }
  end
end
