require 'test_helper'

class MemberMapLeafletCssTest < ActiveSupport::TestCase
  test 'local stylesheet includes required Leaflet tile layout rules' do
    stylesheet = Rails.root.join('app/assets/stylesheets/application.bootstrap.scss').read

    assert_includes stylesheet, '.leaflet-container .leaflet-tile'
    assert_includes stylesheet, 'max-width: none !important'
    assert_includes stylesheet, '.leaflet-tile-loaded'
    assert_includes stylesheet, 'visibility: inherit'
    assert_includes stylesheet, '.leaflet-pane'
    assert_includes stylesheet, 'z-index: 400'
    assert_includes stylesheet, '.leaflet-zoom-animated'
    assert_includes stylesheet, 'transform-origin: 0 0'
  end
end
