module MembershipSettingsHelper
  def invitation_expiry_display(setting)
    hours = setting.invitation_expiry_hours
    suffix = hours >= 24 ? " (#{hours / 24} #{'day'.pluralize(hours / 24)})" : ''
    safe_join([content_tag(:strong, hours), " hours#{suffix}"])
  end

  def login_link_expiry_display(setting)
    hours = setting.login_link_expiry_hours
    suffix = hours >= 24 ? " (#{hours / 24} #{'day'.pluralize(hours / 24)})" : ''
    safe_join([content_tag(:strong, hours), " hours#{suffix}"])
  end

  def application_verification_expiry_display(setting)
    hours = setting.application_verification_expiry_hours
    suffix = hours >= 24 ? " (#{hours / 24} #{'day'.pluralize(hours / 24)})" : ''
    safe_join([content_tag(:strong, hours), " hours#{suffix}"])
  end
end
