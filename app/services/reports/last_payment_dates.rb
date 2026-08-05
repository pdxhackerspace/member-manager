module Reports
  # Resolves the most recent payment date for many users at once.
  #
  # `User#most_recent_payment_date` costs three queries per user, which is fine for one
  # profile page and ruinous for a report that walks hundreds of members. This produces
  # the same answer for a whole set in three grouped queries, and deliberately mirrors
  # that method's semantics: dates come from the user's own columns plus the maxima of
  # the PayPal, Recharge, and cash payment tables, and timestamps are converted with
  # `to_date` in the application time zone rather than in SQL.
  class LastPaymentDates
    # rows: [id, last_payment_date, recharge_most_recent_payment_date] tuples
    def self.for(rows)
      new(rows).call
    end

    def initialize(rows)
      @rows = rows
    end

    def call
      return {} if user_ids.empty?

      paypal = PaypalPayment.where(user_id: user_ids).group(:user_id).maximum(:transaction_time)
      recharge = RechargePayment.where(user_id: user_ids).group(:user_id).maximum(:processed_at)
      cash = CashPayment.where(user_id: user_ids).group(:user_id).maximum(:paid_on)

      @rows.each_with_object({}) do |(id, last_payment_date, recharge_most_recent), result|
        candidates = [
          last_payment_date,
          recharge_most_recent&.to_date,
          paypal[id]&.to_date,
          recharge[id]&.to_date,
          cash[id]
        ]
        latest = candidates.compact.max
        result[id] = latest if latest
      end
    end

    private

    def user_ids
      @user_ids ||= @rows.map(&:first)
    end
  end
end
