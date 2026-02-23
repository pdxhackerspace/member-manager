module UsersHelper
  # Build a URL that toggles one filter while preserving all other active filters.
  # If the filter is already active with the same value, clicking removes it.
  # Passing nil as filter_value always removes that filter key.
  def stacking_filter_path(filter_key, filter_value)
    new_params = @filter_params.dup
    if filter_value.nil? || new_params[filter_key].to_s == filter_value.to_s
      new_params.delete(filter_key)
    else
      new_params[filter_key] = filter_value
    end
    users_path(new_params)
  end
end
