require 'test_helper'

class IncidentReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_local_auth_enabled = Rails.application.config.x.local_auth.enabled
    Rails.application.config.x.local_auth.enabled = true
    sign_in_as_admin
  end

  teardown do
    Rails.application.config.x.local_auth.enabled = @original_local_auth_enabled
  end

  test 'new renders the form' do
    get new_incident_report_path

    assert_response :success
    assert_select 'form'
    assert_select '#other_explanation_field'
  end

  test 'create saves a valid report' do
    assert_difference 'IncidentReport.count', 1 do
      post incident_reports_path, params: { incident_report: valid_params }
    end

    assert_redirected_to incident_report_path(IncidentReport.last)
  end

  test 'create with type other requires an explanation' do
    assert_no_difference 'IncidentReport.count' do
      post incident_reports_path,
           params: { incident_report: valid_params(incident_type: 'other', other_type_explanation: '') }
    end

    assert_response :unprocessable_content
  end

  test 'create shows which validations failed instead of only a generic alert' do
    post incident_reports_path,
         params: { incident_report: valid_params(incident_type: 'other', other_type_explanation: '') }

    assert_response :unprocessable_content
    assert_select 'div.alert-danger', /prevented this incident report from being saved/
    assert_select 'div.alert-danger li', /Other type explanation/
  end

  test 'create redisplays submitted values after a validation failure' do
    post incident_reports_path,
         params: { incident_report: valid_params(subject: 'Screaming woman',
                                                 incident_type: 'other',
                                                 other_type_explanation: '') }

    assert_response :unprocessable_content
    assert_select 'input[name=?][value=?]', 'incident_report[subject]', 'Screaming woman'
  end

  test 'other explanation field is required and visible when other is selected' do
    post incident_reports_path,
         params: { incident_report: valid_params(incident_type: 'other', other_type_explanation: '') }

    assert_response :unprocessable_content
    assert_select '#other_explanation_field' do |field|
      assert_no_match(/display:\s*none/, field.first['style'].to_s)
    end
    assert_select 'input[name=?][required=?]', 'incident_report[other_type_explanation]', 'required'
  end

  test 'other explanation field is not required when another type is selected' do
    get new_incident_report_path

    assert_response :success
    assert_select 'input[name=?][required]', 'incident_report[other_type_explanation]', count: 0
  end

  test 'create with type other succeeds when an explanation is given' do
    assert_difference 'IncidentReport.count', 1 do
      post incident_reports_path,
           params: { incident_report: valid_params(incident_type: 'other',
                                                   other_type_explanation: 'Trespassing') }
    end

    assert_equal 'Trespassing', IncidentReport.last.other_type_explanation
  end

  private

  def valid_params(overrides = {})
    {
      incident_date: Date.current.to_s,
      subject: 'Test incident',
      incident_type: 'damage',
      other_type_explanation: '',
      status: 'draft',
      description: 'Something happened.',
      resolution: ''
    }.merge(overrides)
  end

  def sign_in_as_admin
    account = local_accounts(:active_admin)
    post local_login_path, params: {
      session: { email: account.email, password: 'localpassword123' }
    }
  end
end
