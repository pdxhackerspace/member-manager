module Reports
  # The common case: the report is just a scope, so the count is one aggregate query.
  class ScopeQuery < BaseQuery
    def initialize(scope)
      super()
      @scope = scope
    end

    def count
      # Eager-loading and ordering are for display; neither changes how many rows match,
      # and both make the count query needlessly expensive.
      @scope.except(:includes, :eager_load, :order).count
    end

    def relation
      @scope
    end
  end
end
