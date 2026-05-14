class FuzzExistingMemberCoordinates < ActiveRecord::Migration[8.1]
  class UserRecord < ActiveRecord::Base
    self.table_name = 'users'
  end

  EARTH_RADIUS_MILES = 3958.8
  BLOCK_MILES = 0.04

  def up
    max_blocks = ENV.fetch('GEOCODING_FUZZ_BLOCKS', '4').to_f
    return unless max_blocks.positive?

    UserRecord.where.not(mailing_latitude: nil).where.not(mailing_longitude: nil).find_each do |user|
      fuzzed = fuzz_coordinate(
        latitude: user.mailing_latitude.to_f,
        longitude: user.mailing_longitude.to_f,
        max_blocks: max_blocks
      )
      user.update_columns(
        mailing_latitude: fuzzed.fetch(:latitude),
        mailing_longitude: fuzzed.fetch(:longitude),
        updated_at: Time.current
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def fuzz_coordinate(latitude:, longitude:, max_blocks:)
    distance_miles = Random.rand([1.0, max_blocks].min..max_blocks) * BLOCK_MILES
    bearing = Random.rand(0.0...(2 * Math::PI))
    angular_distance = distance_miles / EARTH_RADIUS_MILES
    latitude_radians = degrees_to_radians(latitude)
    longitude_radians = degrees_to_radians(longitude)

    fuzzed_latitude = Math.asin(
      (Math.sin(latitude_radians) * Math.cos(angular_distance)) +
      (Math.cos(latitude_radians) * Math.sin(angular_distance) * Math.cos(bearing))
    )
    fuzzed_longitude = longitude_radians + Math.atan2(
      Math.sin(bearing) * Math.sin(angular_distance) * Math.cos(latitude_radians),
      Math.cos(angular_distance) - (Math.sin(latitude_radians) * Math.sin(fuzzed_latitude))
    )

    {
      latitude: radians_to_degrees(fuzzed_latitude).round(6),
      longitude: radians_to_degrees(fuzzed_longitude).round(6)
    }
  end

  def degrees_to_radians(degrees)
    degrees * Math::PI / 180
  end

  def radians_to_degrees(radians)
    radians * 180 / Math::PI
  end
end
