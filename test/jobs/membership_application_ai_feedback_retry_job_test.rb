require 'test_helper'

class MembershipApplicationAiFeedbackRetryJobTest < ActiveJob::TestCase
  setup do
    @profile = ai_ollama_profiles(:application_status)
    @profile.update!(
      enabled: true,
      base_url: 'http://ollama.test:11434',
      model: 'test-model',
      prompt: 'You review applications.'
    )
    ai_ollama_profiles(:default).update!(base_url: '', model: '')
  end

  test 'processes submitted applications with missing AI feedback' do
    app = MembershipApplication.create!(email: 'retry-ai@example.com', status: 'submitted', submitted_at: Time.current)
    app.update_columns(ai_feedback_last_error: 'timeout', updated_at: Time.current)

    payload = {
      'score' => 2,
      'score_rationale' => 'Looks good.',
      'recommendation' => 'accept',
      'questions' => [],
      'garbage' => false,
      'garbage_reason' => nil
    }
    stub_result = Ollama::ChatCompletion::Result.new(true, JSON.generate(payload), nil)

    with_chat_completion_stub(stub_result) do
      MembershipApplicationAiFeedbackRetryJob.perform_now
    end

    app.reload
    assert app.ai_feedback_processed?
    assert_equal 2, app.ai_feedback_score
    assert_nil app.ai_feedback_last_error
  end

  test 'skips applications that already have AI feedback' do
    app = MembershipApplication.create!(
      email: 'already-processed@example.com',
      status: 'submitted',
      submitted_at: Time.current,
      ai_feedback_processed_at: Time.current,
      ai_feedback_score: 1,
      ai_feedback_questions: []
    )

    called = false
    with_chat_completion_stub(lambda { |**|
      called = true
      Ollama::ChatCompletion::Result.new(true, '{}', nil)
    }) do
      MembershipApplicationAiFeedbackRetryJob.perform_now
    end

    assert_not called
    assert_equal 1, app.reload.ai_feedback_score
  end

  test 'skips draft applications' do
    app = MembershipApplication.create!(email: 'draft-skip@example.com', status: 'draft')

    called = false
    with_chat_completion_stub(lambda { |**|
      called = true
      Ollama::ChatCompletion::Result.new(true, '{}', nil)
    }) do
      MembershipApplicationAiFeedbackRetryJob.perform_now
    end

    assert_not called
    assert_nil app.reload.ai_feedback_processed_at
  end

  private

  def with_chat_completion_stub(result_or_callable)
    original_call = Ollama::ChatCompletion.method(:call)
    replacement = result_or_callable.respond_to?(:call) ? result_or_callable : ->(**) { result_or_callable }
    Ollama::ChatCompletion.define_singleton_method(:call) do |**kwargs|
      replacement.call(**kwargs)
    end
    yield
  ensure
    Ollama::ChatCompletion.define_singleton_method(:call, original_call)
  end
end
