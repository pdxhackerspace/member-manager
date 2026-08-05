module Api
  class UsersController < AdminController
    def search
      q = params[:q].to_s.strip

      if q.blank?
        render json: []
        return
      end

      pattern = "%#{q.downcase}%"

      # Email is encrypted, so it cannot be matched by substring like the other fields.
      # A whole address still resolves through the lookup digest.
      users = User.where(
        "LOWER(COALESCE(full_name, '')) LIKE :p " \
        "OR LOWER(COALESCE(username, '')) LIKE :p " \
        'OR EXISTS (SELECT 1 FROM unnest(aliases) AS a WHERE LOWER(a) LIKE :p)',
        p: pattern
      ).or(User.by_any_email(q)).ordered_by_display_name.limit(20)

      render json: users.map { |u| { id: u.id, name: u.display_name, email: u.email } }
    end
  end
end
