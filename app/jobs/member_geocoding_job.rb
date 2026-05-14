class MemberGeocodingJob < ApplicationJob
  queue_as :default

  def perform(user_id = nil)
    geocoder = Geocoding::NominatimClient.new
    return geocode_one(User.find_by(id: user_id), geocoder) if user_id.present?

    users_needing_geocoding.find_each.with_index do |user, index|
      sleep throttle_seconds if index.positive? && throttle_seconds.positive?
      geocode_one(user, geocoder)
    end
  end

  private

  def users_needing_geocoding
    User.non_service_accounts
        .where.not(mailing_address: [nil, ''])
        .where(mailing_geocoded_at: nil)
  end

  def geocode_one(user, geocoder)
    return if user.blank? || user.mailing_address.blank?

    result = geocoder.geocode(user.mailing_address)
    updates = { mailing_geocoded_at: Time.current, updated_at: Time.current }
    if result.present?
      fuzzed_result = Geocoding::CoordinateFuzzer.call(
        latitude: result.fetch(:latitude),
        longitude: result.fetch(:longitude)
      )
      updates[:mailing_latitude] = fuzzed_result.fetch(:latitude)
      updates[:mailing_longitude] = fuzzed_result.fetch(:longitude)
    end

    user.update_columns(updates)
  end

  def throttle_seconds
    return 0 if Rails.env.test?

    ENV.fetch('GEOCODING_THROTTLE_SECONDS', '1').to_f
  end
end
