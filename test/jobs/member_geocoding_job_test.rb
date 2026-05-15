require 'test_helper'

class MemberGeocodingJobTest < ActiveJob::TestCase
  FakeGeocoder = Struct.new(:result, :addresses) do
    def geocode(address)
      addresses << address
      result
    end
  end

  test 'geocodes a single member and stores coordinates' do
    user = users(:one)
    user.update_columns(
      mailing_address: '7608 N Interstate Ave, Portland, OR',
      mailing_latitude: nil,
      mailing_longitude: nil,
      mailing_geocoded_at: nil
    )
    geocoder = FakeGeocoder.new({ latitude: 45.581678.to_d, longitude: -122.682156.to_d }, [])

    with_env('GEOCODING_FUZZ_BLOCKS' => '0') do
      with_geocoder(geocoder) do
        MemberGeocodingJob.perform_now(user.id)
      end
    end

    user.reload
    assert_equal 45.581678, user.mailing_latitude.to_f
    assert_equal(-122.682156, user.mailing_longitude.to_f)
    assert_not_nil user.mailing_geocoded_at
    assert_equal ['7608 N Interstate Ave, Portland, OR'], geocoder.addresses
  end

  test 'appends default city and state when mailing address has no locality' do
    DefaultSetting.instance.update!(map_default_city: 'Portland', map_default_state: 'Oregon')
    user = users(:one)
    user.update_columns(
      mailing_address: '7608 N Interstate Ave',
      mailing_latitude: nil,
      mailing_longitude: nil,
      mailing_geocoded_at: nil
    )
    geocoder = FakeGeocoder.new({ latitude: 45.581678.to_d, longitude: -122.682156.to_d }, [])

    with_env('GEOCODING_FUZZ_BLOCKS' => '0') do
      with_geocoder(geocoder) do
        MemberGeocodingJob.perform_now(user.id)
      end
    end

    assert_equal ['7608 N Interstate Ave, Portland, Oregon'], geocoder.addresses
  end

  test 'does not append default city and state when mailing address already has them' do
    DefaultSetting.instance.update!(map_default_city: 'Portland', map_default_state: 'Oregon')
    user = users(:one)
    user.update_columns(
      mailing_address: '7608 N Interstate Ave, Portland, OR',
      mailing_latitude: nil,
      mailing_longitude: nil,
      mailing_geocoded_at: nil
    )
    geocoder = FakeGeocoder.new({ latitude: 45.581678.to_d, longitude: -122.682156.to_d }, [])

    with_env('GEOCODING_FUZZ_BLOCKS' => '0') do
      with_geocoder(geocoder) do
        MemberGeocodingJob.perform_now(user.id)
      end
    end

    assert_equal ['7608 N Interstate Ave, Portland, OR'], geocoder.addresses
  end

  test 'fuzzes coordinates when geocoding stores a result' do
    user = users(:one)
    user.update_columns(
      mailing_address: '7608 N Interstate Ave, Portland, OR',
      mailing_latitude: nil,
      mailing_longitude: nil,
      mailing_geocoded_at: nil
    )
    geocoder = FakeGeocoder.new({ latitude: 45.581678.to_d, longitude: -122.682156.to_d }, [])

    with_env('GEOCODING_FUZZ_BLOCKS' => '4') do
      with_geocoder(geocoder) do
        with_random(1.0) do
          MemberGeocodingJob.perform_now(user.id)
        end
      end
    end

    user.reload
    assert_not_equal 45.581678, user.mailing_latitude.to_f
    assert_in_delta 45.581678, user.mailing_latitude.to_f, 0.001
    assert_in_delta(-122.682156, user.mailing_longitude.to_f, 0.001)
  end

  test 'hourly run geocodes members with unattempted mailing addresses' do
    users(:one).update_columns(
      mailing_address: '7608 N Interstate Ave, Portland, OR',
      mailing_latitude: nil,
      mailing_longitude: nil,
      mailing_geocoded_at: nil
    )
    users(:two).update_columns(
      mailing_address: 'Already geocoded',
      mailing_latitude: 45.5,
      mailing_longitude: -122.6,
      mailing_geocoded_at: Time.current
    )
    geocoder = FakeGeocoder.new({ latitude: 45.581678.to_d, longitude: -122.682156.to_d }, [])

    with_env('GEOCODING_FUZZ_BLOCKS' => '0') do
      with_geocoder(geocoder) do
        MemberGeocodingJob.perform_now
      end
    end

    assert_includes geocoder.addresses, '7608 N Interstate Ave, Portland, OR'
    assert_not_includes geocoder.addresses, 'Already geocoded'
  end

  test 'records attempted geocoding when no result is found' do
    user = users(:one)
    user.update_columns(
      mailing_address: 'No result address',
      mailing_latitude: nil,
      mailing_longitude: nil,
      mailing_geocoded_at: nil
    )
    geocoder = FakeGeocoder.new(nil, [])

    with_geocoder(geocoder) do
      MemberGeocodingJob.perform_now(user.id)
    end

    user.reload
    assert_nil user.mailing_latitude
    assert_nil user.mailing_longitude
    assert_not_nil user.mailing_geocoded_at
  end

  test 'coordinate fuzzer can be disabled' do
    with_env('GEOCODING_FUZZ_BLOCKS' => '0') do
      result = Geocoding::CoordinateFuzzer.call(latitude: 45.581678.to_d, longitude: -122.682156.to_d)

      assert_equal 45.581678, result.fetch(:latitude).to_f
      assert_equal(-122.682156, result.fetch(:longitude).to_f)
    end
  end

  test 'coordinate fuzzer keeps fuzz near the original coordinate' do
    with_env('GEOCODING_FUZZ_BLOCKS' => '4') do
      result = nil
      with_random(1.0) do
        result = Geocoding::CoordinateFuzzer.call(latitude: 45.581678.to_d, longitude: -122.682156.to_d)
      end

      assert_not_equal 45.581678, result.fetch(:latitude).to_f
      assert_in_delta 45.581678, result.fetch(:latitude).to_f, 0.001
      assert_in_delta(-122.682156, result.fetch(:longitude).to_f, 0.001)
    end
  end

  private

  def with_geocoder(geocoder)
    original_new = Geocoding::NominatimClient.method(:new)
    Geocoding::NominatimClient.define_singleton_method(:new) { geocoder }
    yield
  ensure
    Geocoding::NominatimClient.define_singleton_method(:new) do |*args, **kwargs, &block|
      original_new.call(*args, **kwargs, &block)
    end
  end

  def with_env(values)
    originals = values.keys.index_with { |key| ENV.fetch(key, nil) }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    originals.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  def with_random(value)
    original_rand = Random.method(:rand)
    Random.define_singleton_method(:rand) { |_range| value }
    yield
  ensure
    Random.define_singleton_method(:rand) do |*args, **kwargs, &block|
      original_rand.call(*args, **kwargs, &block)
    end
  end
end
