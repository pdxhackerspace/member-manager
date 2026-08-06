require 'csv'

class SlackUsersController < AdminController
  # email is absent deliberately: the column holds ciphertext, so ordering by it returns
  # rows in an order unrelated to the addresses shown.
  SORTABLE_COLUMNS = %w[display_name is_admin is_owner is_bot deleted].freeze

  def index
    # Calculate counts from ALL slack users (before filtering)
    all_slack_users = SlackUser.all
    @total_count = all_slack_users.count
    @linked_count = all_slack_users.where.not(user_id: nil).count
    @unlinked_count = all_slack_users.where(user_id: nil, is_bot: false, dont_link: false).count
    @dont_link_count = all_slack_users.where(dont_link: true).count
    @admin_count = all_slack_users.where(is_admin: true).count
    @owner_count = all_slack_users.where(is_owner: true).count
    @bot_count = all_slack_users.where(is_bot: true).count
    @human_count = all_slack_users.where(is_bot: false).count
    @active_count = all_slack_users.active.count
    @inactive_count = all_slack_users.inactive.count
    @deactivated_count = all_slack_users.deactivated.count

    # Build filtered query using shared method (with eager loading for display)
    @slack_users = build_filtered_query.includes(:user)

    # Store sort info for view
    @sort_column = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'display_name'
    @sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'

    # Track if any filter is active
    @filter_active = params[:linked].present? || params[:is_admin].present? ||
                     params[:is_owner].present? || params[:is_bot].present? || params[:status].present?
    @filtered_count = @slack_users.count if @filter_active

    # Store filter/sort params for links using shared method
    @list_params = extract_filter_params

    # Load users for link modal (only if there are unlinked entries)
    @all_users = User.ordered_by_display_name if @unlinked_count.positive?
  end

  def show
    @slack_user = SlackUser.includes(:user).find(params[:id])

    # Get all users for the selection dropdown (if no match found)
    @all_users = User.ordered_by_display_name if @slack_user.user.nil?

    # Store filter/sort params FIRST for use in view links
    # This ensures params are captured before any processing
    @nav_params = extract_filter_params

    # Rebuild the same filtered/sorted query from the index page for navigation
    nav_query = build_filtered_query

    ordered_ids = nav_query.pluck(:id)
    current_index = ordered_ids.index(@slack_user.id)

    if current_index
      @previous_slack_user = current_index.positive? ? SlackUser.find(ordered_ids[current_index - 1]) : nil
      @next_slack_user = current_index < ordered_ids.length - 1 ? SlackUser.find(ordered_ids[current_index + 1]) : nil
    else
      # Current user not in filtered list - show no navigation
      @previous_slack_user = nil
      @next_slack_user = nil
    end
  end

  def link_user
    @slack_user = SlackUser.find(params[:id])
    user = User.find(params[:user_id])

    @slack_user.update!(user_id: user.id)

    if params[:from_index] == 'true'
      redirect_to slack_users_path(extract_filter_params),
                  notice: "Linked #{@slack_user.display_name} to #{user.display_name}."
    else
      redirect_to slack_user_path(@slack_user),
                  notice: "Linked to #{user.display_name}."
    end
  end

  def unlink_user
    @slack_user = SlackUser.find(params[:id])
    user = @slack_user.user

    if user.blank?
      redirect_to slack_user_path(@slack_user), alert: 'Slack user is not linked to a member.'
      return
    end

    SlackUser.transaction do
      @slack_user.update!(user_id: nil)
      clear_user_slack_fields!(user, @slack_user)
    end

    MemberSource.for('slack').refresh_statistics!
    redirect_to slack_user_path(@slack_user), notice: "Disassociated from #{user.display_name}."
  end

  def toggle_dont_link
    @slack_user = SlackUser.find(params[:id])
    new_value = !@slack_user.dont_link
    @slack_user.update!(dont_link: new_value)

    notice = if new_value
               "#{@slack_user.display_name} marked as Don't Link."
             else
               "#{@slack_user.display_name} unmarked as Don't Link."
             end

    if params[:from_index] == 'true'
      redirect_to slack_users_path(extract_filter_params), notice: notice
    else
      redirect_to slack_user_path(@slack_user), notice: notice
    end
  end

  def create_member
    @slack_user = SlackUser.find(params[:id])
    result = Slack::MemberCreator.call(slack_user: @slack_user)

    if result.success?
      redirect_to user_path(result.user), notice: "Created member '#{result.user.display_name}' from Slack user."
    elsif @slack_user.user_id.present?
      redirect_to slack_users_path(extract_filter_params), alert: result.message
    else
      redirect_to slack_users_path(extract_filter_params),
                  alert: "Failed to create member: #{result.message}"
    end
  end

  def sync
    unless MemberSource.enabled?('slack')
      redirect_to slack_users_path, alert: 'Slack source is disabled.'
      return
    end

    update_members = ActiveModel::Type::Boolean.new.cast(params[:update_members]) == true
    Slack::UserSyncJob.perform_later(update_members: update_members)

    notice = if update_members
               'Slack sync started. Matching members will be linked and member accounts will be updated.'
             else
               'Slack sync started. Matching members will be linked.'
             end
    redirect_to slack_users_path, notice: notice
  end

  def import_members
    if params[:file].blank?
      redirect_to slack_users_path, alert: 'Please choose a CSV file to import.'
      return
    end

    counts = Slack::CsvMemberImporter.new.call(params[:file])

    parts = []
    parts << "#{counts[:imported]} imported"
    parts << "#{counts[:updated]} updated"
    parts << "#{counts[:skipped]} skipped" if counts[:skipped].positive?

    redirect_to slack_users_path, notice: "Import complete: #{parts.join(', ')}."
  rescue CSV::MalformedCSVError => e
    redirect_to slack_users_path, alert: "Invalid CSV: #{e.message}"
  end

  def import_analytics
    if params[:file].blank?
      redirect_to slack_users_path, alert: 'Please choose a CSV file to import.'
      return
    end

    counts = Slack::CsvAnalyticsImporter.new.call(params[:file])

    parts = []
    parts << "#{counts[:updated]} updated"
    parts << "#{counts[:skipped]} skipped" if counts[:skipped].positive?

    redirect_to slack_users_path, notice: "Analytics import complete: #{parts.join(', ')}."
  rescue CSV::MalformedCSVError => e
    redirect_to slack_users_path, alert: "Invalid CSV: #{e.message}"
  end

  private

  # Extract filter/sort params from request for use in navigation links
  def extract_filter_params
    filter_params = {}
    filter_params[:linked] = params[:linked] if params[:linked].present?
    filter_params[:is_admin] = params[:is_admin] if params[:is_admin].present?
    filter_params[:is_owner] = params[:is_owner] if params[:is_owner].present?
    filter_params[:is_bot] = params[:is_bot] if params[:is_bot].present?
    filter_params[:status] = params[:status] if params[:status].present?
    filter_params[:sort] = params[:sort] if params[:sort].present?
    filter_params[:direction] = params[:direction] if params[:direction].present?
    filter_params
  end

  # Build a filtered and sorted query based on current params
  def build_filtered_query
    query = SlackUser.all

    # Apply linked/unlinked/dont_link filter
    case params[:linked]
    when 'yes'
      query = query.where.not(user_id: nil)
    when 'no'
      # Unlinked = no user_id, not a bot, not marked as dont_link
      query = query.where(user_id: nil, is_bot: false, dont_link: false)
    when 'dont_link'
      query = query.where(dont_link: true)
    end

    # Apply role filters
    query = query.where(is_admin: true) if params[:is_admin] == 'yes'
    query = query.where(is_admin: false) if params[:is_admin] == 'no'
    query = query.where(is_owner: true) if params[:is_owner] == 'yes'
    query = query.where(is_owner: false) if params[:is_owner] == 'no'

    # Apply type filters
    query = query.where(is_bot: true) if params[:is_bot] == 'yes'
    query = query.where(is_bot: false) if params[:is_bot] == 'no'

    query = apply_status_filter(query)

    # Apply sorting — use Arel nodes to avoid string interpolation (CodeQL SQL injection rule)
    sort_column = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'display_name'
    sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
    col_node = SlackUser.arel_table[sort_column]
    direction_node = sort_direction == 'desc' ? col_node.desc : col_node.asc
    query.order(Arel::Nodes::NullsLast.new(direction_node))
  end

  def apply_status_filter(query)
    case params[:status]
    when 'active'
      query.active
    when 'inactive'
      query.inactive
    when 'deactivated'
      query.deactivated
    else
      query
    end
  end

  def clear_user_slack_fields!(user, slack_user)
    updates = { updated_at: Time.current }
    updates[:slack_id] = nil if user.slack_id == slack_user.slack_id
    updates[:slack_handle] = nil if user.slack_id == slack_user.slack_id || user.slack_handle == slack_user.username

    user.update_columns(updates) if updates.keys != [:updated_at]
  end
end
