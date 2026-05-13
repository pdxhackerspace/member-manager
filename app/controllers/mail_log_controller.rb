class MailLogController < AdminController
  before_action :set_log_entry, only: :show

  def index
    @log_entries = MailLogEntry.newest_first
                               .includes(queued_mail: :recipient, actor: [])
                               .limit(200)
  end

  def show; end

  private

  def set_log_entry
    @log_entry = MailLogEntry.includes(queued_mail: :recipient, actor: []).find(params[:id])
  end
end
