class ParkingNoticeExpirationJob < ApplicationJob
  queue_as :default

  def perform
    ParkingNotice.needing_expiration.find_each do |notice|
      notice.expire!
      notice.record_journal_entry!('parking_notice_expired')

      template_key = notice.permit? ? 'parking_permit_expired' : 'parking_ticket_expired'
      notice.enqueue_notification!(template_key)
    end
  end
end
