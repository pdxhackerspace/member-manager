module MemberZoneConfig
  BASE_URL_ENV = 'MEMBER_ZONE_BASE_URL'.freeze
  # Pre-rename name for BASE_URL_ENV. Honoured so deployments that still export the
  # old variable keep working until their environment is updated.
  LEGACY_BASE_URL_ENV = 'MEMBER_MANAGER_BASE_URL'.freeze

  # Public base URL used to build externally reachable webhook URLs.
  def self.base_url
    ENV[BASE_URL_ENV].presence || ENV[LEGACY_BASE_URL_ENV].presence
  end
end
