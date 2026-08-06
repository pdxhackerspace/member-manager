class NagSettingsController < AdminController
  include Pagy::Method

  PER_PAGE = 50

  before_action :set_nag_setting, only: %i[show update]

  def index
    NagSetting.seed_defaults!
    @nag_settings = NagSetting.ordered
    @slack_due_count = Nags::SlackSignupEligibility.count_due
    @slack_without_slack_count = Nags::SlackSignupEligibility.total_without_slack
    @slack_source_enabled = MemberSource.enabled?('slack')
    @slack_email_template = EmailTemplate.find_by(key: 'slack_signup_nag')
    @membership_setting = MembershipSetting.instance
  end

  def show
    load_slack_show_data
  end

  def update
    if @nag_setting.update(nag_setting_params)
      redirect_to nag_settings_path, notice: "#{@nag_setting.name} updated."
    else
      load_slack_show_data if @nag_setting.key == 'slack_signup'
      render(@nag_setting.key == 'slack_signup' ? :show : :index, status: :unprocessable_content)
    end
  end

  private

  def set_nag_setting
    @nag_setting = NagSetting.find_by!(key: params[:key])
  end

  def nag_setting_params
    params.expect(nag_setting: [:enabled])
  end

  def load_slack_show_data
    @pagy, @due_users = pagy(Nags::SlackSignupEligibility.due, limit: PER_PAGE)
    @slack_due_count = @pagy.count
    @slack_without_slack_count = Nags::SlackSignupEligibility.total_without_slack
    @slack_source_enabled = MemberSource.enabled?('slack')
    @slack_email_template = EmailTemplate.find_by(key: 'slack_signup_nag')
    @membership_setting = MembershipSetting.instance
  end
end
