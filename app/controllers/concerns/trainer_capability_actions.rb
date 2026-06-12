module TrainerCapabilityActions
  extend ActiveSupport::Concern

  def add_trainer_capability
    unless current_user_admin?
      redirect_to record_training_path, alert: 'Only admins can manage trainer capabilities.'
      return
    end

    existing = TrainerCapability.find_by(user: @trainee, training_topic: @training_topic)
    if existing
      redirect_to trainer_capability_return_path(@trainee),
                  notice: "#{@trainee.display_name} can already train #{@training_topic.name}."
      return
    end

    capability = TrainerCapability.new(user: @trainee, training_topic: @training_topic)

    if capability.save
      ensure_trainee_trained_for_trainer_capability
      log_trainer_capability_added
      notify_trainer_capability_granted
      redirect_to trainer_capability_return_path(@trainee),
                  notice: "#{@trainee.display_name} can now train others in #{@training_topic.name}."
    else
      redirect_to trainer_capability_return_path(@trainee),
                  alert: "Failed to add trainer capability: #{capability.errors.full_messages.join(', ')}"
    end
  end

  def remove_trainer_capability
    unless current_user_admin?
      redirect_to record_training_path, alert: 'Only admins can manage trainer capabilities.'
      return
    end

    capability = TrainerCapability.find_by(user: @trainee, training_topic: @training_topic)

    if capability&.destroy
      log_trainer_capability_removed
      redirect_to trainer_capability_return_path(@trainee),
                  notice: "Removed #{@training_topic.name} trainer capability from #{@trainee.display_name}."
    else
      redirect_to trainer_capability_return_path(@trainee),
                  alert: "#{@trainee.display_name} did not have trainer capability for #{@training_topic.name}."
    end
  end

  private

  def ensure_trainee_trained_for_trainer_capability
    return if Training.exists?(trainee: @trainee, training_topic: @training_topic)

    Training.create!(
      trainee: @trainee,
      trainer: current_user,
      training_topic: @training_topic,
      trained_at: Time.current
    )
  end

  def log_trainer_capability_added
    Journal.create!(
      user: @trainee,
      actor_user: current_user,
      action: 'trainer_capability_added',
      changes_json: {
        'trainer_capability' => {
          'topic' => @training_topic.name,
          'granted_by' => current_user.display_name,
          'granted_at' => Time.current.iso8601
        }
      },
      changed_at: Time.current,
      highlight: true
    )
  end

  def log_trainer_capability_removed
    Journal.create!(
      user: @trainee,
      actor_user: current_user,
      action: 'trainer_capability_removed',
      changes_json: {
        'trainer_capability' => {
          'topic' => @training_topic.name,
          'revoked_by' => current_user.display_name,
          'revoked_at' => Time.current.iso8601
        }
      },
      changed_at: Time.current,
      highlight: true
    )
  end

  def notify_trainer_capability_granted
    return if @trainee.email.blank?

    QueuedMail.enqueue(:trainer_capability_granted, @trainee,
                       reason: "Can now train #{@training_topic.name}",
                       training_topic: @training_topic.name)
  end

  def trainer_capability_return_path(trainee)
    return user_path(trainee, anchor: 'training-access-section') if params[:return_to] == 'profile'

    record_training_path(
      trainer_user_id: trainee.id,
      topic_id: params[:return_topic_id].presence,
      trainee_ids: params[:return_trainee_ids].presence
    )
  end
end
