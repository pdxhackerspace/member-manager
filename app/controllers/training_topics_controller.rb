# Manages training topics. Topic setup needs training.topics.manage; curators reach the topic
# page for the topics whose resources or documents they look after.
class TrainingTopicsController < AuthenticatedController
  before_action :set_training_topic, only: %i[edit update revoke_training revoke_trainer_capability]
  before_action -> { require_privilege!(:'training.topics.manage') }, only: %i[index create destroy]
  before_action :require_topic_page_access!, only: %i[edit update]
  before_action :require_revoke_training_permission!, only: %i[revoke_training]
  before_action :require_trainer_capability_permission!, only: %i[revoke_trainer_capability]

  def index
    @training_topics = TrainingTopic.order(:name)
  end

  def edit
    load_edit_associations
  end

  def create
    @training_topic = TrainingTopic.new(training_topic_params)
    @training_topics = TrainingTopic.order(:name)

    if @training_topic.save
      redirect_to training_topics_path, notice: 'Training topic created successfully.'
    else
      render :index, status: :unprocessable_content
    end
  end

  def update
    # Curators can reach this page for their topics but cannot rename or retarget them.
    permitted_params = can?(:'training.topics.manage') ? training_topic_params : {}

    if permitted_params.empty? || @training_topic.update(permitted_params)
      redirect_to edit_training_topic_path(@training_topic), notice: 'Training topic updated successfully.'
    else
      load_edit_associations
      render :edit, status: :unprocessable_content
    end
  end

  def revoke_training
    user = User.find(params[:user_id])

    # Delete all trainings for this user and topic
    deleted_count = @training_topic.trainings.where(trainee: user).destroy_all.count

    if deleted_count.positive?
      redirect_to edit_training_topic_path(@training_topic), notice: "Training revoked for #{user.display_name}."
    else
      redirect_to edit_training_topic_path(@training_topic),
                  alert: "No training found to revoke for #{user.display_name}."
    end
  end

  def revoke_trainer_capability
    user = User.find(params[:user_id])

    # Delete the trainer capability
    trainer_capability = TrainerCapability.find_by(user: user, training_topic: @training_topic)

    if trainer_capability&.destroy
      redirect_to edit_training_topic_path(@training_topic),
                  notice: "Trainer capability revoked for #{user.display_name}."
    else
      redirect_to edit_training_topic_path(@training_topic),
                  alert: "No trainer capability found to revoke for #{user.display_name}."
    end
  end

  def destroy
    @training_topic = TrainingTopic.find(params[:id])

    if @training_topic.trainings.any? || @training_topic.trainer_capabilities.any?
      redirect_to training_topics_path,
                  alert: 'Cannot delete training topic that has trainings or trainer capabilities.'
    else
      @training_topic.destroy
      redirect_to training_topics_path, notice: 'Training topic deleted successfully.'
    end
  end

  private

  def set_training_topic
    @training_topic = TrainingTopic.find(params[:id])
  end

  def require_topic_page_access!
    return if can?(:'training.topics.manage')
    return if can?(:'training.topics.manage_links', topic: @training_topic)
    return if can?(:'training.documents.manage', topic: @training_topic)

    redirect_to root_path, alert: "You don't have permission to manage that training topic."
  end

  # Revoking training removes privileges, so it is gated the same way granting is: a trainer
  # must not be able to strip a director of theirs.
  def require_revoke_training_permission!
    return if true_user&.may_revoke_training?(@training_topic)

    redirect_to edit_training_topic_path(@training_topic),
                alert: "You don't have permission to revoke training for that topic."
  end

  def require_trainer_capability_permission!
    return if true_user&.may_manage_trainer_capability?(@training_topic)

    redirect_to edit_training_topic_path(@training_topic),
                alert: 'You do not have permission to manage trainer capabilities.'
  end

  def load_edit_associations
    trained_user_ids = Training.where(training_topic_id: @training_topic.id).select(:trainee_id).distinct
    @trained_users = User.where(id: trained_user_ids).order(:full_name, :email)
    @trainer_users = @training_topic.trainers.order(:full_name, :email)
    @users_for_search = User.ordered_by_display_name
    @topic_documents = @training_topic.documents.ordered
    @topic_roles = @training_topic.topic_roles.joins(:role).includes(role: :privileges).order('roles.name')
    @available_roles = Role.ordered
  end

  def training_topic_params
    params.expect(training_topic: %i[name offered_to_members])
  end
end
