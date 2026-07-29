module ParkingStatusFiltering
  # Members see active notices by default; cleared ones are hidden until asked for.
  DEFAULT_PARKING_STATUSES = %w[active].freeze

  private

  # Statuses selected via the stacking filter pills on the member parking tab.
  # No param means the default (active only); 'all' means no status filter.
  def selected_parking_statuses
    raw = params[:statuses].to_s
    return [] if raw == 'all'

    selected = raw.split(',').map(&:strip).uniq & ParkingNotice::STATUSES
    selected.presence || DEFAULT_PARKING_STATUSES
  end

  def apply_parking_status_filter(scope)
    statuses = selected_parking_statuses
    statuses.any? ? scope.where(status: statuses) : scope
  end
end
