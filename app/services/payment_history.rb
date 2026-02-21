class PaymentHistory
  def self.for_user(user, event_type: nil)
    scope = PaymentEvent.for_user(user).ordered
    scope = scope.by_type(event_type) if event_type.present?
    scope
  end

  def self.for_sheet_entry(sheet_entry)
    return PaymentEvent.none unless sheet_entry.user

    for_user(sheet_entry.user)
  end
end
