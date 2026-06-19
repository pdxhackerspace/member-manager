module MembershipApplications
  class ApplicantStatusTiming
    OVERDUE_APOLOGY_FRAGMENT_KEY = 'application_status_overdue_apology'.freeze

    def self.for(application, now: Time.current)
      new(application, now: now).call
    end

    def initialize(application, now: Time.current)
      @application = application
      @now = now
    end

    def call
      estimate = ProcessingTimeStats.applicant_estimate
      waiting_seconds = waiting_duration_seconds
      average_seconds = estimate[:average_seconds]
      overdue = pending? && average_seconds && waiting_seconds && waiting_seconds > average_seconds

      {
        estimate: estimate,
        waiting_seconds: waiting_seconds,
        waiting_label: waiting_seconds ? ProcessingTimeStats.format_duration(waiting_seconds) : nil,
        show_apology: overdue,
        apology_content: overdue ? apology_content : nil
      }
    end

    private

    attr_reader :application, :now

    def pending?
      !application.approved? && !application.rejected?
    end

    def waiting_duration_seconds
      opened_at = application.submitted_at || application.created_at
      return nil unless opened_at

      [now - opened_at, 0].max
    end

    def apology_content
      TextFragment.content_for(OVERDUE_APOLOGY_FRAGMENT_KEY).presence
    end
  end
end
