module TextFragments
  # Rewrites GitHub web URLs so fetches receive file bytes (raw) instead of HTML UI pages.
  class SourceUrlNormalizer
    GITHUB_HOSTS = %w[github.com www.github.com].freeze

    def self.call(url_string)
      new(url_string).call
    end

    def initialize(url_string)
      @url_string = url_string.to_s.strip
    end

    def call
      return @url_string if @url_string.blank?

      uri = URI.parse(@url_string)
      return @url_string unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      return @url_string unless GITHUB_HOSTS.include?(uri.host&.downcase)

      path = uri.path.to_s
      if (converted = blob_to_raw(path))
        return rebuilt_https_uri(uri, converted)
      end
      if (converted = github_raw_path_to_raw_host(path))
        return rebuilt_https_uri(uri, converted)
      end

      @url_string
    rescue URI::InvalidURIError
      @url_string
    end

    private

    # /owner/repo/blob/ref/path/to/file -> raw.githubusercontent.com path
    def blob_to_raw(path)
      m = path.match(%r{\A/([^/]+)/([^/]+)/blob/([^/]+)/(.+)\z}o)
      return nil unless m

      owner, repo, ref, filepath = m.captures
      "/#{owner}/#{repo}/#{ref}/#{filepath}"
    end

    # /owner/repo/raw/ref/path/to/file (links from GitHub UI)
    def github_raw_path_to_raw_host(path)
      m = path.match(%r{\A/([^/]+)/([^/]+)/raw/([^/]+)/(.+)\z}o)
      return nil unless m

      owner, repo, ref, filepath = m.captures
      "/#{owner}/#{repo}/#{ref}/#{filepath}"
    end

    def rebuilt_https_uri(original, raw_path)
      URI::HTTPS.build(
        host: 'raw.githubusercontent.com',
        path: raw_path,
        query: original.query,
        fragment: original.fragment
      ).to_s
    end
  end
end
