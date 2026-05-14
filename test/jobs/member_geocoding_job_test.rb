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

    with_geocoder(geocoder) do
      MemberGeocodingJob.perform_now(user.id)
    end

    user.reload
    assert_equal 45.581678, user.mailing_latitude.to_f
    assert_equal(-122.682156, user.mailing_longitude.to_f)
    assert_not_nil user.mailing_geocoded_at
    assert_equal ['7608 N Interstate Ave, Portland, OR'], geocoder.addresses
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

    with_geocoder(geocoder) do
      MemberGeocodingJob.perform_now
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
end
