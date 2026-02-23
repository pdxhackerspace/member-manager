class OnboardingController < AdminController
  before_action :set_user, only: [:payment, :save_payment, :access, :save_rfid, :save_training]

  # Step 1: Member Info
  def member_info
    @user = User.new
  end

  def create_member
    @user = User.new(member_params)
    @user.membership_status = 'unknown'
    @user.dues_status = 'unknown'
    @user.active = false

    if @user.save
      redirect_to onboard_payment_path(@user), status: :see_other
    else
      render :member_info, status: :unprocessable_entity
    end
  end

  # Step 2: Payment Info
  def payment
    @plans = MembershipPlan.shared.primary.visible.ordered
  end

  def save_payment
    membership_type = params[:membership_type]

    case membership_type
    when 'paying'
      if params[:custom_plan] == '1'
        plan = MembershipPlan.create!(
          name: "Custom - #{@user.display_name}",
          cost: params[:plan_cost].to_f,
          billing_frequency: params[:plan_billing_frequency],
          plan_type: 'primary',
          manual: true,
          visible: false,
          user: @user
        )
        @user.update!(
          membership_status: 'paying',
          payment_type: params[:plan_payment_type] || 'unknown',
          membership_plan: plan,
          active: true,
          dues_status: 'current'
        )
      else
        plan = MembershipPlan.find(params[:membership_plan_id])
        @user.update!(
          membership_status: 'paying',
          payment_type: plan.manual? ? 'cash' : 'unknown',
          membership_plan: plan,
          active: true,
          dues_status: 'current'
        )
      end
    when 'sponsored'
      @user.update!(
        membership_status: 'sponsored',
        payment_type: 'sponsored',
        active: true,
        dues_status: 'current'
      )
    when 'guest'
      @user.update!(
        membership_status: 'guest',
        payment_type: 'inactive',
        active: false,
        dues_status: 'unknown'
      )
    end

    redirect_to onboard_access_path(@user), status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    @plans = MembershipPlan.shared.primary.visible.ordered
    flash.now[:alert] = "Error: #{e.message}"
    render :payment, status: :unprocessable_entity
  end

  # Step 3: Building Access
  def access
    @rfids = @user.rfids
    @building_access_topic = TrainingTopic.find_by("LOWER(name) LIKE ?", "%building access%")
    @has_building_access_training = @building_access_topic &&
      Training.exists?(trainee: @user, training_topic: @building_access_topic)
  end

  def save_rfid
    rfid_code = params[:rfid_code]&.strip
    if rfid_code.present?
      rfid = @user.rfids.build(rfid: rfid_code, notes: "Added during onboarding")
      if rfid.save
        flash[:notice] = "RFID key fob added."
      else
        flash[:alert] = "Could not add RFID: #{rfid.errors.full_messages.join(', ')}"
      end
    else
      flash[:alert] = "Please enter an RFID code."
    end
    redirect_to onboard_access_path(@user), status: :see_other
  end

  def save_training
    topic = TrainingTopic.find_by("LOWER(name) LIKE ?", "%building access%")
    unless topic
      flash[:alert] = "Building Access training topic not found. Please create it under Settings > Training Topics."
      redirect_to onboard_access_path(@user), status: :see_other
      return
    end

    unless Training.exists?(trainee: @user, training_topic: topic)
      training = Training.create!(
        trainee: @user,
        trainer: current_user,
        training_topic: topic,
        trained_at: Time.current
      )

      Journal.create!(
        user: @user,
        actor_user: current_user,
        action: 'training_added',
        changes_json: {
          'training' => {
            'topic' => topic.name,
            'trainer' => current_user.display_name,
            'trained_at' => training.trained_at.iso8601
          }
        },
        changed_at: Time.current,
        highlight: true
      )
    end

    flash[:notice] = "Building Access training recorded."
    redirect_to onboard_access_path(@user), status: :see_other
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def member_params
    params.require(:user).permit(:full_name, :email, :username)
  end
end
