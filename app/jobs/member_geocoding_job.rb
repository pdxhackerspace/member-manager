class MemberGeocodingJob < ApplicationJob
  queue_as :default

  STATE_ABBREVIATIONS = {
    'alabama' => 'al',
    'alaska' => 'ak',
    'arizona' => 'az',
    'arkansas' => 'ar',
    'california' => 'ca',
    'colorado' => 'co',
    'connecticut' => 'ct',
    'delaware' => 'de',
    'florida' => 'fl',
    'georgia' => 'ga',
    'hawaii' => 'hi',
    'idaho' => 'id',
    'illinois' => 'il',
    'indiana' => 'in',
    'iowa' => 'ia',
    'kansas' => 'ks',
    'kentucky' => 'ky',
    'louisiana' => 'la',
    'maine' => 'me',
    'maryland' => 'md',
    'massachusetts' => 'ma',
    'michigan' => 'mi',
    'minnesota' => 'mn',
    'mississippi' => 'ms',
    'missouri' => 'mo',
    'montana' => 'mt',
    'nebraska' => 'ne',
    'nevada' => 'nv',
    'new hampshire' => 'nh',
    'new jersey' => 'nj',
    'new mexico' => 'nm',
    'new york' => 'ny',
    'north carolina' => 'nc',
    'north dakota' => 'nd',
    'ohio' => 'oh',
    'oklahoma' => 'ok',
    'oregon' => 'or',
    'pennsylvania' => 'pa',
    'rhode island' => 'ri',
    'south carolina' => 'sc',
    'south dakota' => 'sd',
    'tennessee' => 'tn',
    'texas' => 'tx',
    'utah' => 'ut',
    'vermont' => 'vt',
    'virginia' => 'va',
    'washington' => 'wa',
    'west virginia' => 'wv',
    'wisconsin' => 'wi',
    'wyoming' => 'wy'
  }.freeze

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

    result = geocoder.geocode(geocoding_address(user.mailing_address))
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

  def geocoding_address(address)
    settings = DefaultSetting.instance
    address = address.to_s.strip
    city = settings.map_default_city.to_s.strip
    state = settings.map_default_state.to_s.strip
    return address if address.blank? || city.blank? || state.blank?

    normalized_address = address.downcase
    city_present = normalized_address.match?(/\b#{Regexp.escape(city.downcase)}\b/)
    state_present = state_tokens(state).any? do |token|
      normalized_address.match?(/\b#{Regexp.escape(token)}\b/)
    end
    return address if city_present && state_present

    locality = if city_present
                 state
               else
                 "#{city}, #{state}"
               end
    "#{address}, #{locality}"
  end

  def state_tokens(state)
    normalized = state.downcase
    tokens = [normalized]
    if normalized.length == 2
      full_state = STATE_ABBREVIATIONS.key(normalized)
      tokens << full_state if full_state.present?
    else
      abbreviation = STATE_ABBREVIATIONS[normalized]
      tokens << abbreviation if abbreviation.present?
    end
    tokens
  end

  def throttle_seconds
    return 0 if Rails.env.test?

    ENV.fetch('GEOCODING_THROTTLE_SECONDS', '1').to_f
  end
end
