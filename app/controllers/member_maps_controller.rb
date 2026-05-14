class MemberMapsController < AdminController
  EARTH_RADIUS_MILES = 3958.8

  def show
    prepare_map_data
  end

  private

  def prepare_map_data
    apply_map_settings
    apply_member_marker_data
  end

  def apply_map_settings
    settings = DefaultSetting.instance
    @map_center = {
      latitude: settings.map_center_latitude.to_f,
      longitude: settings.map_center_longitude.to_f
    }
    @map_radius_miles = settings.map_radius_miles.to_f
  end

  def apply_member_marker_data
    scope = map_member_scope
    @map_missing_coordinates_count = scope.where(mailing_latitude: nil).or(scope.where(mailing_longitude: nil)).count

    marker_data = build_marker_data(scope)
    @map_markers = marker_data.fetch(:markers)
    @map_mapped_count = @map_markers.size
    @map_out_of_radius_count = marker_data.fetch(:out_of_radius_count)
  end

  def map_member_scope
    User.where(active: true)
        .non_service_accounts
        .non_legacy
  end

  def build_marker_data(scope)
    markers = []
    out_of_radius_count = 0

    users_with_coordinates(scope).find_each do |user|
      distance = distance_from_map_center(user)
      if distance > @map_radius_miles
        out_of_radius_count += 1
      else
        markers << marker_for(user, distance)
      end
    end

    { markers: markers, out_of_radius_count: out_of_radius_count }
  end

  def users_with_coordinates(scope)
    scope.where.not(mailing_latitude: nil)
         .where.not(mailing_longitude: nil)
         .ordered_by_display_name
  end

  def distance_from_map_center(user)
    distance_miles_between(
      @map_center[:latitude],
      @map_center[:longitude],
      user.mailing_latitude.to_f,
      user.mailing_longitude.to_f
    )
  end

  def marker_for(user, distance)
    {
      name: user.display_name,
      latitude: user.mailing_latitude.to_f,
      longitude: user.mailing_longitude.to_f,
      distance_miles: distance.round(2),
      profile_path: user_path(user)
    }
  end

  def distance_miles_between(from_latitude, from_longitude, to_latitude, to_longitude)
    from_lat = degrees_to_radians(from_latitude)
    to_lat = degrees_to_radians(to_latitude)
    delta_lat = degrees_to_radians(to_latitude - from_latitude)
    delta_lng = degrees_to_radians(to_longitude - from_longitude)

    a = (Math.sin(delta_lat / 2)**2) +
        (Math.cos(from_lat) * Math.cos(to_lat) * (Math.sin(delta_lng / 2)**2))
    2 * EARTH_RADIUS_MILES * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  end

  def degrees_to_radians(degrees)
    degrees * Math::PI / 180
  end
end
