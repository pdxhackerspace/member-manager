# Attaches and detaches roles on a training topic. Attaching a role decides who receives its
# privileges, so like role configuration this is admin-only rather than gated on topic
# management: a topic manager must not be able to grant themselves privileges.
class TrainingTopicRolesController < AdminController
  before_action :set_training_topic

  def create
    topic_role = @training_topic.topic_roles.build(topic_role_params)

    if topic_role.save
      redirect_to edit_training_topic_path(@training_topic),
                  notice: "#{topic_role.role.name} attached to #{@training_topic.name}."
    else
      redirect_to edit_training_topic_path(@training_topic),
                  alert: "Could not attach role: #{topic_role.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    topic_role = @training_topic.topic_roles.find(params[:id])
    role_name = topic_role.role.name
    topic_role.destroy

    redirect_to edit_training_topic_path(@training_topic),
                notice: "#{role_name} removed from #{@training_topic.name}."
  end

  private

  def set_training_topic
    @training_topic = TrainingTopic.find(params[:training_topic_id])
  end

  def topic_role_params
    params.expect(training_topic_role: %i[role_id member_source])
  end
end
