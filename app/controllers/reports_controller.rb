class ReportsController < AdminController
  include Pagy::Method

  PER_PAGE = 25

  before_action :load_counts, only: %i[index show charts]
  before_action :load_report, only: :show

  # Landing page: every report as a card, grouped by category, with live counts.
  def index
    @grouped = Reports::Catalog.grouped
    @attention = Reports::Catalog.reports.select { |report| report.attention? && @counts[report.key].to_i.positive? }
  end

  # A single report. Only this report's rows are loaded.
  def show
    @pagy, @rows = pagy(@report.query.relation, limit: PER_PAGE)
    @locals = @report.locals.merge(@report.query.page_locals(@rows))
  end

  def charts
    @charts = Reports::ChartData.new.call
  end

  def update_user
    user = User.find(params[:user_id])
    key = params[:anchor].presence || 'membership-status-unknown'
    notice = apply_user_action(user, params[:action_type], key)

    return redirect_to reports_path, alert: 'Invalid action.' if notice.nil?

    redirect_to report_path(key), notice: notice
  end

  private

  def load_counts
    @counts = Reports::Catalog.counts
  end

  def load_report
    @report = Reports::Catalog.find(params[:key])
    redirect_to reports_path, alert: 'Unknown report.' if @report.nil?
  end

  # Returns the flash notice, or nil when the action is not recognised.
  def apply_user_action(user, action_type, key)
    case action_type
    when 'activate', 'deactivate' then toggle_active(user, action_type)
    when 'ban' then set_membership_status(user, 'banned')
    when 'deceased' then set_membership_status(user, 'deceased')
    when 'paying' then set_membership_status(user, 'paying')
    when 'sponsored', 'guest' then set_status_or_payment_type(user, action_type, key)
    when 'cash', 'paypal', 'recharge' then set_payment_type(user, action_type)
    when 'payment_guest' then set_payment_type(user, 'guest')
    when 'payment_sponsored' then set_payment_type(user, 'sponsored')
    end
  end

  def toggle_active(user, action_type)
    unless user.service_account?
      return "Active status for #{user.display_name} is determined by membership and dues status."
    end

    active = action_type == 'activate'
    user.update!(active: active)
    "#{user.display_name} #{active ? 'activated' : 'deactivated'}."
  end

  def set_membership_status(user, status)
    user.update!(membership_status: status)
    "#{user.display_name} membership status set to #{status}."
  end

  def set_payment_type(user, type)
    user.update!(payment_type: type)
    "#{user.display_name} payment type set to #{type}."
  end

  # On the payment-type report these buttons mean payment type; everywhere else they
  # mean membership status.
  def set_status_or_payment_type(user, value, key)
    return set_payment_type(user, value) if key == 'payment-type-unknown'

    set_membership_status(user, value)
  end
end
