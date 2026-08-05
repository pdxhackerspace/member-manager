module Reports
  # Access-log rollups for a set of users, each with its own cutoff timestamp.
  #
  # The cutoffs are computed in Ruby (so `end_of_day` keeps using `Time.zone` exactly as
  # the per-user code did) and joined into the query as a VALUES list, which keeps the
  # whole rollup to a single round trip regardless of how many members are involved.
  class AccessLogAggregates
    BOUNDS = { exclusive: '>', inclusive: '>=' }.freeze

    # cutoffs: { user_id => Time or nil }. A nil cutoff means "count every access log".
    #
    # bound: whether a log landing exactly on the cutoff counts. The two callers differ
    # and the difference is deliberate — "badged in since their last payment" excludes
    # the payment instant itself, while "badged in within the last year" includes the
    # window's first instant, which is what the ranged `where` it replaced did.
    def initialize(cutoffs, bound: :exclusive)
      raise ArgumentError, "unknown bound #{bound}" unless BOUNDS.key?(bound)

      @cutoffs = cutoffs
      @operator = BOUNDS.fetch(bound)
    end

    # => { user_id => { access_count:, most_recent_at: } }, users with no matching logs omitted
    def totals
      return {} if @cutoffs.empty?

      sql = <<~SQL.squish
        SELECT al.user_id AS user_id, COUNT(*) AS access_count, MAX(al.logged_at) AS most_recent_at
        FROM access_logs al
        JOIN (VALUES #{values_list}) AS cutoffs(user_id, cutoff)
          ON cutoffs.user_id = al.user_id
        WHERE cutoffs.cutoff IS NULL OR al.logged_at #{@operator} cutoffs.cutoff
        GROUP BY al.user_id
      SQL

      ActiveRecord::Base.connection.select_all(sql).to_h do |row|
        [row['user_id'].to_i,
         { access_count: row['access_count'].to_i, most_recent_at: timestamp(row['most_recent_at']) }]
      end
    end

    # => { user_id => [AccessLog, ...] }, most recent first, at most `limit` per user
    def recent(limit:)
      return {} if @cutoffs.empty?

      sql = <<~SQL.squish
        SELECT * FROM (
          SELECT al.*, ROW_NUMBER() OVER (PARTITION BY al.user_id ORDER BY al.logged_at DESC) AS access_rank
          FROM access_logs al
          JOIN (VALUES #{values_list}) AS cutoffs(user_id, cutoff)
            ON cutoffs.user_id = al.user_id
          WHERE cutoffs.cutoff IS NULL OR al.logged_at #{@operator} cutoffs.cutoff
        ) ranked
        WHERE ranked.access_rank <= #{limit.to_i}
      SQL

      AccessLog.find_by_sql(sql).group_by(&:user_id)
    end

    private

    def values_list
      @values_list ||= @cutoffs.map do |user_id, cutoff|
        cutoff_sql = cutoff ? "#{quote(cutoff.utc)}::timestamp" : 'NULL::timestamp'
        "(#{user_id.to_i}::bigint, #{cutoff_sql})"
      end.join(', ')
    end

    def quote(value)
      ActiveRecord::Base.connection.quote(value)
    end

    def timestamp(value)
      return value if value.blank? || value.is_a?(Time)

      Time.find_zone('UTC').parse(value.to_s)&.in_time_zone
    end
  end
end
