module Geocoding
  class CoordinateFuzzer
    EARTH_RADIUS_MILES = 3958.8
    BLOCK_MILES = 0.04

    def self.call(latitude:, longitude:)
      new.call(latitude: latitude, longitude: longitude)
    end

    def initialize(max_blocks: ENV.fetch('GEOCODING_FUZZ_BLOCKS', '4'))
      @max_blocks = max_blocks.to_f
    end

    def call(latitude:, longitude:)
      return { latitude: latitude, longitude: longitude } unless fuzz?

      distance_miles = Random.rand(min_blocks..@max_blocks) * BLOCK_MILES
      bearing = Random.rand(0.0...(2 * Math::PI))
      fuzzed = offset_coordinate(latitude.to_f, longitude.to_f, distance_miles, bearing)

      {
        latitude: fuzzed.fetch(:latitude).round(6).to_d,
        longitude: fuzzed.fetch(:longitude).round(6).to_d
      }
    end

    private

    def fuzz?
      @max_blocks.positive?
    end

    def min_blocks
      [1.0, @max_blocks].min
    end

    def offset_coordinate(latitude, longitude, distance_miles, bearing)
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
        latitude: radians_to_degrees(fuzzed_latitude),
        longitude: radians_to_degrees(fuzzed_longitude)
      }
    end

    def degrees_to_radians(degrees)
      degrees * Math::PI / 180
    end

    def radians_to_degrees(radians)
      radians * 180 / Math::PI
    end
  end
end
