class MemberParkingPermitsController < AuthenticatedController
  def new
    @parking_notice = ParkingNotice.new(
      notice_type: 'permit',
      expires_at: 7.days.from_now
    )
  end

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

  # Members may close (clear) only their own active permits — never tickets.
  def close
    permit = current_user.parking_notices.permits.active_notices.find(params[:id])
    permit.clear!(current_user)
    permit.record_journal_entry!('parking_notice_cleared', actor: current_user)

    redirect_to user_path(current_user, tab: :parking), notice: 'Parking permit closed.'
  rescue ActiveRecord::RecordNotFound
    redirect_to user_path(current_user, tab: :parking),
                alert: 'That parking permit is not available to close.'
  end

  private

  def member_parking_permit_params
    params.expect(
      parking_notice: %i[description location location_detail expires_at]
    )
  end
end
