module MembershipApplications
  class ProcessingTimeStats
    RECENT_WINDOW = 1.month
    APPLICANT_ESTIMATE_MULTIPLIER = 1.25

    def self.call(since: RECENT_WINDOW.ago)
      new(since: since).call
    end

    def self.format_duration(seconds)
      return nil if seconds.nil?

      seconds = seconds.round
      if seconds < 60
        'less than a minute'
      elsif seconds < 3600
        minutes = (seconds / 60.0).round
        "#{minutes} #{'minute'.pluralize(minutes)}"
      elsif seconds < 86_400
        hours = (seconds / 3600.0).round
        "#{hours} #{'hour'.pluralize(hours)}"
      else
        days = (seconds / 86_400.0).round
        "#{days} #{'day'.pluralize(days)}"
      end
    end

    def self.applicant_estimate(since: RECENT_WINDOW.ago, multiplier: APPLICANT_ESTIMATE_MULTIPLIER)
      stats = call(since: since)
      average_seconds = stats[:average_seconds]
      return stats.merge(estimated_seconds: nil, estimated_label: nil) unless average_seconds

      estimated_seconds = average_seconds * multiplier
      stats.merge(
        estimated_seconds: estimated_seconds,
        estimated_label: format_duration(estimated_seconds)
      )
    end

    def initialize(since:)
      @since = since
    end

    def call
      count, average_seconds = finalized_scope.pick(
        Arel.sql('COUNT(*)'),
        Arel.sql("AVG(EXTRACT(EPOCH FROM (reviewed_at - #{opened_at_sql})))")
      )

      count = count.to_i
      average_seconds = average_seconds&.to_f
      {
        count: count,
        average_seconds: average_seconds,
        average_label: count.positive? ? self.class.format_duration(average_seconds) : nil
      }
    end

    private

    attr_reader :since

    def opened_at_sql
      @opened_at_sql ||= 'COALESCE(membership_applications.submitted_at, membership_applications.created_at)'
    end

    def finalized_scope
      MembershipApplication.finalized
                           .where(reviewed_at: since..)
                           .where("#{opened_at_sql} IS NOT NULL")
                           .where("reviewed_at >= #{opened_at_sql}")
    end
  end
end
