class MessagesController < AuthenticatedController
  before_action :require_admin!

  def create
    recipient = User.find(params[:recipient_id])
    message = current_user.sent_messages.build(
      recipient: recipient,
      subject: params[:subject],
      body: params[:body]
    )

    if message.save
      MemberMailer.message_received(message).deliver_later
      redirect_to user_path(recipient, tab: :messages), notice: 'Message sent.'
    else
      redirect_to user_path(recipient, tab: :messages),
                  alert: "Failed to send message: #{message.errors.full_messages.join(', ')}"
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to users_path, alert: 'Recipient not found.'
  end
end
