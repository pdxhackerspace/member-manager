# The navbar, as data.
#
# The navbar is the only way a non-administrator with privileges reaches anything: the
# dashboard is administrator-only and `root` points at it, so a privilege holder signing in
# lands on their own profile. Without an entry here, an enforced privilege is unreachable
# unless the holder knows the URL.
#
# Nothing here enforces anything — each destination gates itself. An entry with no
# `privilege:` is administrator-only, which is the default rather than an oversight; later
# phases move entries off it as their privilege gets enforced.
module MainNavigationHelper
  # Controllers whose pages count as "inside Settings" for the purpose of highlighting.
  SETTINGS_CONTROLLERS = %w[
    settings applications application_groups text_fragments documents incoming_webhooks
    rooms printers application_form_pages application_form_questions ai_ollama_profiles
    ai_providers interests member_sources rfid_readers access_controllers
    access_controller_types authentik_webhooks default_settings membership_settings
    payment_processors nag_settings roles training_topics
  ].freeze

  def main_nav_entries
    [
      { key: 'members', label: 'Members', items: members_nav_items },
      { key: 'payments', label: 'Payments', items: payments_nav_items },
      { key: 'training', label: 'Training', path: training_catalog_path,
        controllers: %w[training_catalog], always: true },
      { key: 'journal', label: 'Journal', path: journals_path, privilege: :'journal.view' },
      { key: 'building', label: 'Building', items: building_nav_items },
      { key: 'admin', label: 'Admin', items: admin_nav_items }
    ]
  end

  # Sections keep only the entries this account can see; a section with nothing left does
  # not render, and one left holding a single entry renders as a flat link rather than a
  # dropdown containing one thing.
  def visible_nav_entries
    main_nav_entries.filter_map do |entry|
      next (entry if nav_entry_visible?(entry)) unless entry[:items]

      items = compact_nav_dividers(entry[:items].select { |item| item == :divider || nav_entry_visible?(item) })
      next if items.none? { |item| item != :divider }

      real = items.reject { |item| item == :divider }
      real.one? ? real.first : entry.merge(items: items)
    end
  end

  def nav_entry_visible?(entry)
    return true if entry[:always]
    # The hub is a directory, so it appears for anyone with a row to open rather than
    # needing a grant of its own — see SettingsHelper#visible_settings_items.
    return settings_nav_visible? if entry[:privilege] == :settings_hub
    return current_user_admin? if entry[:privilege].blank?

    entry[:any_topic] ? can_for_any_topic?(entry[:privilege]) : can?(entry[:privilege])
  end

  # Whether to render the privileged half of the navbar at all.
  def privileged_nav_visible?
    current_user_admin? || visible_nav_entries.any?
  end

  # A parent is active when any of its children is, so nothing has to be maintained by hand.
  def nav_entry_active?(entry)
    return true if entry[:controllers]&.include?(controller_name)
    return true if entry[:path].present? && !entry[:items] && current_page?(entry[:path])

    Array(entry[:items]).any? { |item| item != :divider && nav_entry_active?(item) }
  end

  # Dividers only mean something between two entries: drop them when they end up leading,
  # trailing, or doubled after filtering, or a menu renders a stray rule.
  def compact_nav_dividers(items)
    items
      .chunk_while { |a, b| a == :divider && b == :divider }.map(&:first)
      .drop_while { |item| item == :divider }
      .reverse.drop_while { |item| item == :divider }.reverse
  end

  private

  def settings_nav_visible?
    can?(:'settings.view') || visible_settings_items.any?
  end

  def members_nav_items
    [
      { key: 'members_index', label: 'Members', path: users_path, privilege: :'members.view_list' },
      { key: 'authentik', label: 'Authentik', path: authentik_users_path },
      { key: 'sheet', label: 'Sheet', path: sheet_entries_path },
      { key: 'slack', label: 'Slack', path: slack_users_path },
      :divider,
      { key: 'applications', label: 'Applications', path: membership_applications_path,
        privilege: :'applications.view', controllers: %w[membership_applications] },
      { key: 'incident_reports', label: 'Incident Reports', path: incident_reports_path,
        controllers: %w[incident_reports] }
    ]
  end

  def payments_nav_items
    [
      { key: 'paypal', label: 'PayPal', path: paypal_payments_path, privilege: :'payments.view' },
      { key: 'recharge', label: 'Recharge', path: recharge_payments_path, privilege: :'payments.view' },
      { key: 'kofi', label: 'Ko-Fi', path: kofi_payments_path, privilege: :'payments.view' },
      { key: 'cash', label: 'Cash', path: cash_payments_path },
      :divider,
      { key: 'payment_events', label: 'Payment Events', path: payment_events_path,
        privilege: :'payments.view_events' }
    ]
  end

  def building_nav_items
    [
      { key: 'access_logs', label: 'Access', path: access_logs_path },
      { key: 'parking', label: 'Parking', path: parking_notices_path, controllers: %w[parking_notices] }
    ]
  end

  def admin_nav_items
    [
      { key: 'reports', label: 'Reports', path: reports_path, controllers: %w[reports] },
      { key: 'member_map', label: 'Map', path: member_map_path, controllers: %w[member_maps] },
      { key: 'queued_mail', label: 'Mail queue', path: queued_mails_path,
        privilege: :'queued_mail.view', controllers: %w[queued_mails] },
      { key: 'mail_log', label: 'Mail log', path: mail_log_path,
        privilege: :'mail_log.view', controllers: %w[mail_log] },
      { key: 'settings', label: 'Settings', path: settings_path,
        privilege: :settings_hub, controllers: SETTINGS_CONTROLLERS },
      { key: 'sidekiq', label: 'Sidekiq', path: '/goh7zeeNiezoozaingothu4', target: '_blank' }
    ]
  end
end
