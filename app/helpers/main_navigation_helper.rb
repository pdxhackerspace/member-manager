# Which navbar entries an account can see.
#
# The navbar is the only way a non-administrator with privileges reaches anything: the
# dashboard is administrator-only and `root` points at it, so a privilege holder signing in
# lands on their own profile. Without an entry here, an enforced privilege is unreachable
# unless the holder knows the URL.
#
# Nothing here enforces anything — each destination gates itself. An entry with no privilege
# is administrator-only, which is the default rather than an oversight; later phases move
# entries off it as their privilege gets enforced.
module MainNavigationHelper
  SECTIONS = {
    members: %i[members_index authentik sheet slack applications incident_reports],
    payments: %i[paypal recharge kofi cash payment_events],
    building: %i[access_logs parking],
    admin: %i[reports member_map queued_mail mail_log settings sidekiq]
  }.freeze

  # Flat entries, outside any dropdown.
  FLAT_ITEMS = %i[journal].freeze

  def nav_item_visible?(key)
    case key
    when :members_index then can?(:'members.view_list')
    when :applications then can?(:'applications.view')
    when :paypal, :recharge, :kofi then can?(:'payments.view')
    when :payment_events then can?(:'payments.view_events')
    when :queued_mail then can?(:'queued_mail.view')
    when :mail_log then can?(:'mail_log.view')
    when :settings then settings_nav_visible?
    else current_user_admin?
    end
  end

  # A dropdown appears when at least one of its children does, so reaching a child never
  # depends on holding something extra for its parent.
  def nav_section_visible?(section)
    SECTIONS.fetch(section).any? { |key| nav_item_visible?(key) }
  end

  # Whether to render the privileged half of the navbar at all.
  def privileged_nav_visible?
    return true if current_user_admin?

    SECTIONS.each_key.any? { |section| nav_section_visible?(section) } ||
      FLAT_ITEMS.any? { |key| nav_item_visible?(key) }
  end

  private

  def settings_nav_visible?
    can?(:'settings.view') || visible_settings_items.any?
  end
end
