class MemberParkingPermitsController < AuthenticatedController
  before_action :set_owned_notice, only: %i[show edit update close]
  before_action :require_owned_permit, only: %i[edit update close]

  # Members may view their own permits and tickets.
  def show; end

  def new
    @parking_notice = ParkingNotice.new(
      notice_type: 'permit',
      expires_at: 7.days.from_now
    )
  end

  # Members may edit only their own permits (guarded by require_owned_permit).
  def edit; end

  def create
    @parking_notice = current_user.parking_notices.build(member_parking_permit_params)
    @parking_notice.notice_type = 'permit'
    @parking_notice.issued_by = current_user
    @parking_notice.status = 'active'

    if @parking_notice.save
      @parking_notice.record_journal_entry!('parking_permit_issued', actor: current_user)
      redirect_to user_path(current_user, tab: :parking), notice: 'Parking permit created successfully.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @parking_notice.update(member_parking_permit_params)
      redirect_to user_path(current_user, tab: :parking), notice: 'Parking permit updated.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Members may close (clear) only their own active permits.
  def close
    unless @parking_notice.active?
      redirect_to user_path(current_user, tab: :parking), alert: 'Only active permits can be closed.'
      return
    end

    @parking_notice.clear!(current_user)
    @parking_notice.record_journal_entry!('parking_notice_cleared', actor: current_user)
    redirect_to user_path(current_user, tab: :parking), notice: 'Parking permit closed.'
  end

  private

  def set_owned_notice
    @parking_notice = current_user.parking_notices.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to user_path(current_user, tab: :parking), alert: 'That parking notice is not available.'
  end

  # Tickets are issued by staff; members can view them but not edit, update, or clear.
  def require_owned_permit
    return if @parking_notice.permit?

    redirect_to user_path(current_user, tab: :parking),
                alert: 'Parking tickets are issued by staff and can only be viewed.'
  end

  def member_parking_permit_params
    params.expect(
      parking_notice: %i[description location location_detail expires_at]
    )
  end
end
