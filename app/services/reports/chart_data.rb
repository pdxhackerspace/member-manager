module Reports
  # Data behind the four charts.
  #
  # Month bucketing happens in SQL rather than by loading every payment into Ruby. The
  # timestamps are stored in UTC, so they are shifted into the application time zone
  # before being truncated, which is what `strftime` on a TimeWithZone used to do — a
  # payment just after midnight UTC still lands in the local month it was made.
  class ChartData
    Result = Struct.new(:active_members, :revenue, :churn, :duration)

    BUCKETS = [
      ['< 1 month', 0...1],
      ['1-3 months', 1...3],
      ['3-6 months', 3...6],
      ['6-12 months', 6...12],
      ['1-2 years', 12...24],
      ['2-3 years', 24...36],
      ['3-5 years', 36...60],
      ['5+ years', 60..]
    ].freeze

    def call
      Result.new(
        active_members: active_members_by_month,
        revenue: revenue_by_month,
        churn: churn_by_month,
        duration: duration_distribution
      )
    end

    private

    def local_month(column)
      tz = ActiveRecord::Base.connection.quote(Time.zone.tzinfo.name)
      Arel.sql("to_char(#{column} AT TIME ZONE 'UTC' AT TIME ZONE #{tz}, 'YYYY-MM')")
    end

    def months
      @months ||= begin
        earliest = [
          PaypalPayment.where.not(transaction_time: nil).minimum(:transaction_time),
          RechargePayment.where.not(processed_at: nil).minimum(:processed_at)
        ].compact.min

        cursor = (earliest || 12.months.ago).to_date.beginning_of_month
        last = Time.zone.now.end_of_month.to_date
        list = []
        while cursor <= last
          list << cursor.strftime('%Y-%m')
          cursor = cursor.next_month
        end
        list
      end
    end

    def active_members_by_month
      earliest_payment = {}
      PaypalPayment.joins(:user).where(users: { active: true }).where.not(transaction_time: nil)
                   .group('users.id').minimum('paypal_payments.transaction_time')
                   .each { |id, date| earliest_payment[id] = [earliest_payment[id], date].compact.min }
      RechargePayment.joins(:user).where(users: { active: true }).where.not(processed_at: nil)
                     .group('users.id').minimum('recharge_payments.processed_at')
                     .each { |id, date| earliest_payment[id] = [earliest_payment[id], date].compact.min }

      created_at = User.where(active: true).pluck(:id, :created_at)

      months.map do |month|
        month_end = Date.parse("#{month}-01").end_of_month
        count = created_at.count do |id, created|
          (earliest_payment[id] && earliest_payment[id] <= month_end) || created <= month_end
        end
        { month: month, count: count }
      end
    end

    def revenue_by_month
      paypal = PaypalPayment.where.not(transaction_time: nil).where.not(amount: nil)
                            .group(local_month('transaction_time')).sum(:amount)
      recharge = RechargePayment.where.not(processed_at: nil).where.not(amount: nil)
                                .group(local_month('processed_at')).sum(:amount)

      months.map do |month|
        { month: month, paypal: paypal.fetch(month, 0).to_f.round(2), recharge: recharge.fetch(month, 0).to_f.round(2) }
      end
    end

    def churn_by_month
      scope = User.non_service_accounts.non_legacy
      started = scope.where.not(membership_start_date: nil)
                     .group(Arel.sql("to_char(membership_start_date, 'YYYY-MM')")).count
      ended = scope.where.not(membership_ended_date: nil)
                   .group(Arel.sql("to_char(membership_ended_date, 'YYYY-MM')")).count

      (started.keys + ended.keys).uniq.sort.map do |month|
        { month: month, new_members: started.fetch(month, 0), lapsed_members: ended.fetch(month, 0) }
      end
    end

    def duration_distribution
      spans = User.where.not(membership_start_date: nil)
                  .where.not(membership_ended_date: nil)
                  .non_service_accounts
                  .pluck(:membership_start_date, :membership_ended_date)
                  .map { |start_on, end_on| ((end_on - start_on).to_f / 30.44).round }

      counts = BUCKETS.to_h { |label, range| [label, spans.count { |m| range.cover?(m) }] }

      {
        labels: counts.keys,
        counts: counts.values,
        total: spans.size,
        median: spans.any? ? spans.sort[spans.size / 2] : 0,
        average: spans.any? ? (spans.sum.to_f / spans.size).round(1) : 0
      }
    end
  end
end
