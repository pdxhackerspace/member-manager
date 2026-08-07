# rubocop:disable Rails/Output
class MembershipActiveReconciler
  def initialize(dry_run:, scope: User.all)
    @dry_run = dry_run
    @scope = scope
    @checked = 0
    @stale = []
  end

  def run
    puts(@dry_run ? 'PREVIEW — no changes will be made' : 'Reconciling user active flags')
    puts '=' * 60

    @scope.find_each do |user|
      @checked += 1
      next unless Membership::ActiveStatus.needs_reconciliation?(user)

      @stale << user
      puts stale_line(user)
      Membership::ActiveStatus.reconcile!(user) unless @dry_run
    end

    puts ''
    puts "Checked #{@checked} users"
    puts "Stale: #{@stale.size}"
    if @dry_run
      puts "Run 'rake membership:reconcile_active' to apply changes." if @stale.any?
    else
      puts 'Done.'
    end
  end

  private

  def stale_line(user)
    computed = Membership::ActiveStatus.compute(user)
    parts = ["#{user.display_name} (id #{user.id}): active #{user.active} -> #{computed}"]
    parts << 'payment_type -> inactive' if user.deceased? && user.payment_type != 'inactive'
    "  #{parts.join(', ')}"
  end
end
# rubocop:enable Rails/Output
