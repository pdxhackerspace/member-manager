module Reports
  # Legacy members who have access-log records — either ever, or within a recent window.
  #
  # Both variants used to issue two queries per member on top of the scope; this is two
  # queries in total.
  class LegacyAccessQuery < BaseQuery
    def initialize(since: nil, recent_access_limit: 5)
      super()
      @since = since
      @recent_access_limit = recent_access_limit
    end

    def count
      entries.size
    end

    def relation
      ordered_by_ids(entries.keys)
    end

    # user_id => { access_count:, most_recent_at: }, most recent access first
    def entries
      @entries ||= AccessLogAggregates.new(cutoffs).totals
                                      .sort_by { |_user_id, row| row[:most_recent_at] }
                                      .reverse.to_h
    end

    def page_locals(users)
      page_cutoffs = users.to_h { |user| [user.id, @since] }
      {
        metadata: entries,
        recent_accesses: AccessLogAggregates.new(page_cutoffs).recent(limit: @recent_access_limit)
      }
    end

    private

    def cutoffs
      @cutoffs ||= User.where(legacy: true).non_service_accounts.pluck(:id).index_with { @since }
    end
  end
end
