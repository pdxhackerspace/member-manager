class TrainingRequestsController < AuthenticatedController
  before_action :set_training_request, only: %i[edit update mark_trained dismiss]
  before_action :authorize_responder!, only: %i[edit update mark_trained]
  before_action :authorize_requester!, only: %i[dismiss]

  def new
    @member_requestable_topics = TrainingTopic.available_for_member_requests
  end

  def edit
    @requester = @training_request.user
  end

  def create
    topic = TrainingTopic.available_for_member_requests.find_by(id: training_request_params[:training_topic_id])
    if topic.nil?
      redirect_to new_training_request_path, alert: 'Please select a valid training topic.'
      return
    end

    if training_request_params[:share_contact_info] != '1'
      redirect_to new_training_request_path, alert: 'Please confirm contact sharing to submit your request.'
      return
    end

    request = current_user.training_requests.build(
      training_topic: topic,
      share_contact_info: true
    )

    if request.save
      queue_training_request_emails!(request)
      redirect_to user_path(current_user, tab: :profile),
                  notice: "Your training request for #{topic.name} has been sent."
    else
      redirect_to new_training_request_path, alert: request.errors.full_messages.to_sentence
    end
  end

  def update
    body = params[:training_request][:response_body].to_s.strip
    if body.blank?
      redirect_to edit_training_request_path(@training_request), alert: 'Response message cannot be blank.'
      return
    end

    message = current_user.sent_messages.build(
      recipient: @training_request.user,
      subject: "Training request response: #{@training_request.training_topic.name}",
      body: body
    )

    if message.save
      MemberMailer.message_received(message).deliver_later
      @training_request.respond!(current_user)
      redirect_to user_path(current_user), notice: 'Response sent to member.'
    else
      redirect_to edit_training_request_path(@training_request), alert: message.errors.full_messages.to_sentence
    end
  end

  # Trainer (or admin) records the training directly from the request. Recording a Training
  # marks the pending request(s) responded, so it disappears from every trainer's queue and
  # surfaces a "training completed" notification for the member.
  def mark_trained
    topic = @training_request.training_topic
    trainee = @training_request.user

    if Training.exists?(trainee: trainee, training_topic: topic)
      @training_request.respond!(current_user) if @training_request.pending?
      redirect_back_or_to user_path(current_user),
                          notice: "#{trainee.display_name} is already trained in #{topic.name}."
      return
    end

    result = TrainingRecorder.new(
      current_user: current_user,
      training_topic: topic,
      trainee_ids: [trainee.id.to_s],
      trainer: current_user,
      trained_at: Time.current
    ).call

    if result.recorded_count.positive?
      redirect_back_or_to user_path(current_user),
                          notice: "Recorded training for #{trainee.display_name} in #{topic.name}."
    else
      redirect_back_or_to user_path(current_user),
                          alert: "Could not record training for #{trainee.display_name}."
    end
  end

  # Member dismisses a completed training request so it stops showing on their dashboard.
  def dismiss
    @training_request.dismiss!
    redirect_back_or_to user_path(current_user, tab: :training_history),
                        notice: 'Training update dismissed.'
  end

  private

  def set_training_request
    @training_request = TrainingRequest.find(params[:id])
  end

  def authorize_responder!
    return if current_user_admin?
    if @training_request.pending? && current_user.training_topics.exists?(id: @training_request.training_topic_id)
      return
    end

    redirect_to user_path(current_user), alert: 'You are not allowed to respond to that request.'
  end

  def authorize_requester!
    return if @training_request.user_id == current_user.id

    redirect_to user_path(current_user), alert: 'You are not allowed to update that request.'
  end

  def training_request_params
    params.expect(training_request: %i[training_topic_id share_contact_info])
  end

  def queue_training_request_emails!(request)
    topic = request.training_topic
    requester = request.user
    active_trainers = topic.trainers.active.order(:full_name, :email).to_a
    trainer_names = active_trainers.map(&:display_name).join(', ')
    requester_args = training_request_mail_args(request, recipient_role: 'member', trainer_names: trainer_names)

    QueuedMail.enqueue(
      :training_requested,
      requester,
      reason: "Training requested for #{topic.name}",
      **requester_args
    )

    active_trainers.each do |trainer|
      enqueue_trainer_training_request_mail(request, trainer, trainer_names: trainer_names)
    end
  end

  def training_request_mail_args(request, recipient_role:, trainer_names:)
    {
      training_topic: request.training_topic.name,
      requester_name: request.user.display_name,
      requester_email: request.user.email.to_s,
      requester_slack: request.user.slack_handle.to_s,
      share_contact_info: request.share_contact_info,
      recipient_role: recipient_role,
      trainer_names: trainer_names
    }
  end

  def enqueue_trainer_training_request_mail(request, trainer, trainer_names:)
    return if trainer.email.blank?

    QueuedMail.enqueue(
      :training_requested,
      trainer,
      to: trainer.email,
      reason: "Training request notification for #{request.training_topic.name}",
      **training_request_mail_args(request, recipient_role: 'trainer', trainer_names: trainer_names)
    )
  end
end
