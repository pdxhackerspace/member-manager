class SearchController < AuthenticatedController
  def index
    @q = params[:q].to_s.strip
    return if @q.blank?

    if current_user_admin?
      @admin_search = true
      search_admin
    else
      @admin_search = false
      search_member
    end
  end

  private

  # Encrypted email columns cannot be matched by substring the way names are, so each
  # search widens its name match with an exact lookup of the whole address typed.
  def search_admin
    pattern = "%#{@q.downcase}%"

    @users = User.where(
      "LOWER(COALESCE(full_name, '')) LIKE :p " \
      'OR LOWER(authentik_id) LIKE :p',
      p: pattern
    ).or(User.by_any_email(@q)).order(:full_name).limit(25)
    @authentik_users = AuthentikUser.where(
      "LOWER(COALESCE(full_name, '')) LIKE :p " \
      "OR LOWER(COALESCE(username, '')) LIKE :p " \
      'OR LOWER(authentik_id) LIKE :p',
      p: pattern
    ).or(AuthentikUser.by_email(@q)).order(:full_name).limit(25)
    @sheet_entries = SheetEntry.where(
      "LOWER(COALESCE(name, '')) LIKE :p",
      p: pattern
    ).or(SheetEntry.by_email(@q)).order(:name).limit(25)
    @slack_users = SlackUser.where(
      "LOWER(COALESCE(display_name, '')) LIKE :p " \
      "OR LOWER(COALESCE(real_name, '')) LIKE :p " \
      "OR LOWER(COALESCE(username, '')) LIKE :p",
      p: pattern
    ).or(SlackUser.by_email(@q)).order(:display_name).limit(25)
    @paypal_payments = PaypalPayment.where(
      "LOWER(COALESCE(payer_name, '')) LIKE :p " \
      'OR LOWER(paypal_id) LIKE :p',
      p: pattern
    ).or(PaypalPayment.by_payer_email(@q)).order(transaction_time: :desc).limit(25)
    @recharge_payments = RechargePayment.where(
      "LOWER(COALESCE(customer_name, '')) LIKE :p " \
      'OR LOWER(recharge_id) LIKE :p',
      p: pattern
    ).or(RechargePayment.by_customer_email(@q)).order(processed_at: :desc).limit(25)
    @kofi_payments = KofiPayment.where(
      "LOWER(COALESCE(from_name, '')) LIKE :p " \
      'OR LOWER(kofi_transaction_id) LIKE :p',
      p: pattern
    ).or(KofiPayment.by_email(@q)).order(timestamp: :desc).limit(25)
  end

  def search_member
    pattern     = "%#{@q.downcase}%"
    visible     = %w[public members]

    # Matching member profiles
    @matching_members = User.where(profile_visibility: visible)
                            .where(
                              "LOWER(COALESCE(full_name, '')) LIKE :p OR LOWER(COALESCE(username, '')) LIKE :p",
                              p: pattern
                            )
                            .order(:full_name)
                            .limit(25)

    # Matching interests → members who have that interest and a visible profile
    matching_interests = Interest.where('LOWER(name) LIKE ?', pattern).alphabetical
    @interest_matches = matching_interests.filter_map do |interest|
      members = interest.users
                        .where(profile_visibility: visible)
                        .order(:full_name)
      next if members.empty?

      { interest: interest, members: members }
    end

    # Matching training topics → trained members + trainers with visible profiles
    matching_topics = TrainingTopic.where('LOWER(name) LIKE ?', pattern).order(:name)
    @training_matches = matching_topics.filter_map do |topic|
      trained = User.joins(:trainings_as_trainee)
                    .where(trainings: { training_topic_id: topic.id })
                    .where(profile_visibility: visible)
                    .distinct
                    .order(:full_name)
      trainers = topic.trainers
                      .where(profile_visibility: visible)
                      .order(:full_name)
      next if trained.empty? && trainers.empty?

      { topic: topic, trained: trained, trainers: trainers }
    end
  end
end
