module Reports
  # Every report answers two questions: how many rows does it have (for the sidebar
  # badge, asked on every page load) and what are the rows on this page (asked only for
  # the report being viewed). Subclasses must make `count` cheap; `relation` may do more
  # work because it runs for one report at a time and is paginated.
  class BaseQuery
    def count
      raise NotImplementedError
    end

    def relation
      raise NotImplementedError
    end

    # Extra locals the report's partial needs for the users on the current page.
    # Runs after pagination, so anything expensive here is bounded by the page size.
    def page_locals(_users)
      {}
    end

    private

    # Preserves a Ruby-computed ordering through pagination without loading every row.
    def ordered_by_ids(ids)
      ids = ids.map(&:to_i)
      return User.none if ids.empty?

      User.where(id: ids)
          .order(Arel.sql("array_position(ARRAY[#{ids.join(',')}]::bigint[], users.id)"))
    end
  end
end
