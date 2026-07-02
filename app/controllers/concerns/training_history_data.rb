module TrainingHistoryData
  private

  # Completed (responded but not yet dismissed) requests the member should be notified about.
  # These surface the "training completed" cards with a dismiss action on the member dashboard.
  def load_completed_training_requests(user)
    @completed_training_requests = user.training_requests
                                       .awaiting_member_acknowledgement
                                       .includes(:training_topic, :responded_by)
                                       .newest_first
  end

  # Loads the data for the member's Training History tab: their own training records plus,
  # for trainers, every record in the topics they are able to train.
  def load_training_history(user)
    @training_history_user = user
    @member_trainings = user.trainings_as_trainee
                            .includes(:training_topic, :trainer)
                            .recent

    @can_view_trainer_history = user.training_topics.exists?
    return unless @can_view_trainer_history

    trainer_topic_ids = user.training_topics.select(:id)
    scope = Training.where(training_topic_id: trainer_topic_ids)
                    .includes(:training_topic, :trainer, :trainee)
                    .recent
    @pagy_trainer_trainings, @trainer_topic_trainings = pagy(scope, limit: 50, page_key: 'training_page')
  end
end
