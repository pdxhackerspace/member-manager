require 'test_helper'

module TextFragments
  class SourceUrlNormalizerTest < ActiveSupport::TestCase
    test 'rewrites github blob URL to raw.githubusercontent.com' do
      url = 'https://github.com/octocat/Hello-World/blob/master/README'
      expected = 'https://raw.githubusercontent.com/octocat/Hello-World/master/README'
      assert_equal expected, SourceUrlNormalizer.call(url)
    end

    test 'rewrites www.github.com blob URL' do
      url = 'https://www.github.com/foo/bar/blob/main/docs/guide.md'
      expected = 'https://raw.githubusercontent.com/foo/bar/main/docs/guide.md'
      assert_equal expected, SourceUrlNormalizer.call(url)
    end

    test 'rewrites github raw path URL' do
      url = 'https://github.com/foo/bar/raw/v1.0.0/LICENSE'
      expected = 'https://raw.githubusercontent.com/foo/bar/v1.0.0/LICENSE'
      assert_equal expected, SourceUrlNormalizer.call(url)
    end

    test 'preserves raw.githubusercontent.com URLs' do
      url = 'https://raw.githubusercontent.com/foo/bar/main/README.md'
      assert_equal url, SourceUrlNormalizer.call(url)
    end

    test 'does not rewrite gist.github.com' do
      url = 'https://gist.github.com/someuser/abc123def'
      assert_equal url, SourceUrlNormalizer.call(url)
    end

    test 'preserves non-GitHub URLs' do
      url = 'https://example.com/page'
      assert_equal url, SourceUrlNormalizer.call(url)
    end
  end
end
