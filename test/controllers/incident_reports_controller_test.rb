require 'test_helper'

class IncidentReportsControllerTest < ActionDispatch::IntegrationTest
  include UsersHelper

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
      assert_not_includes field.first['class'].to_s.split, 'd-none'
    end
    assert_select 'input[name=?][required=?]', 'incident_report[other_type_explanation]', 'required'
  end

  test 'other explanation field is hidden and not required when another type is selected' do
    get new_incident_report_path

    assert_response :success
    assert_select '#other_explanation_field.d-none'
    assert_select 'input[name=?][required]', 'incident_report[other_type_explanation]', count: 0
  end

  test 'incident type toggle is wired to the conditional field controller' do
    get new_incident_report_path

    assert_response :success
    assert_select '[data-controller="conditional-field"][data-conditional-field-match-value="other"]'
    assert_select 'select[data-conditional-field-target="trigger"]'
    assert_select '#other_explanation_field[data-conditional-field-target="field"]'
    assert_select 'input[data-conditional-field-target="input"]'
  end

  test 'create with type other succeeds when an explanation is given' do
    assert_difference 'IncidentReport.count', 1 do
      post incident_reports_path,
           params: { incident_report: valid_params(incident_type: 'other',
                                                   other_type_explanation: 'Trespassing') }
    end

    assert_equal 'Trespassing', IncidentReport.last.other_type_explanation
  end

  # --- Involved members picker ---

  test 'member picker reuses the shared live filter controller' do
    get new_incident_report_path

    assert_response :success
    assert_select '[data-controller="live-filter member-picker"]'
    assert_select 'input[data-live-filter-target="input"][data-member-picker-target="search"]'
    assert_select '[data-live-filter-target="resultsContainer"]'
    assert_select '[data-live-filter-target="noResults"]'
  end

  test 'member picker renders a searchable result row per member' do
    get new_incident_report_path

    assert_response :success
    assert_select '[data-live-filter-target="item"][data-member-picker-target="result"]', User.count

    user = users(:one)
    assert_select "[data-member-picker-target=\"result\"][data-user-id=\"#{user.id}\"]" do
      assert_select '[data-member-picker-id-param=?]', user.id.to_s
      assert_select '[data-member-picker-name-param=?]', user.display_name
    end
  end

  test 'result rows carry the shared live search haystack' do
    get new_incident_report_path

    assert_response :success
    user = users(:one)
    assert_select "[data-member-picker-target=\"result\"][data-user-id=\"#{user.id}\"][data-search-text=?]",
                  user_live_search_text(user)
  end

  test 'create attaches involved members and journals them' do
    user = users(:one)

    assert_difference 'Journal.count', 1 do
      post incident_reports_path,
           params: { incident_report: valid_params(involved_member_ids: ['', user.id.to_s]) }
    end

    assert_equal [user], IncidentReport.last.involved_members.to_a
  end

  test 'blank member id from the picker placeholder input is ignored' do
    post incident_reports_path, params: { incident_report: valid_params(involved_member_ids: ['']) }

    assert_redirected_to incident_report_path(IncidentReport.last)
    assert_empty IncidentReport.last.involved_members
  end

  test 'update can clear every involved member' do
    attributes = valid_params(involved_member_ids: [users(:one).id], reporter: users(:one))
    report = IncidentReport.create!(attributes)
    assert_equal 1, report.involved_members.count

    patch incident_report_path(report),
          params: { incident_report: valid_params(involved_member_ids: ['']) }

    assert_redirected_to incident_report_path(report)
    assert_empty report.reload.involved_members
  end

  test 'selected members are redisplayed after a validation failure' do
    user = users(:one)

    post incident_reports_path,
         params: { incident_report: valid_params(incident_type: 'other',
                                                 other_type_explanation: '',
                                                 involved_member_ids: ['', user.id.to_s]) }

    assert_response :unprocessable_content
    assert_select '[data-member-picker-target="inputs"] input[value=?][data-user-name=?]',
                  user.id.to_s, user.display_name
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
