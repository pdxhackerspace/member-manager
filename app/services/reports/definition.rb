module Reports
  # One report's metadata plus how to build its query. Everything the UI needs — the
  # sidebar, the landing page cards, the report page itself — is derived from these,
  # so adding a report means adding one entry to the catalog rather than editing a
  # controller, a case statement, and two views.
  class Definition
    attr_reader :key, :title, :description, :category, :partial, :locals, :empty_message

    # This is a data definition, so every field is a named keyword rather than a bag of
    # options — the length of the list is the point.
    # rubocop:disable Metrics/ParameterLists
    def initialize(key:, title:, description:, category:, partial:,
                   locals: {}, empty_message: 'Nothing to show here.', attention: false, &query)
      # rubocop:enable Metrics/ParameterLists
      @key = key
      @title = title
      @description = description
      @category = category
      @partial = partial
      @locals = locals
      @empty_message = empty_message
      @attention = attention
      @query = query
    end

    # Non-zero counts on these are something an admin should act on, so they surface at
    # the top of the landing page.
    def attention?
      @attention
    end

    # Builds a fresh query object every call — they memoize, so a caller that needs both
    # the rows and the page locals must hold on to one rather than ask twice.
    def build_query
      @query.call
    end

    def to_param
      key
    end
  end
end
