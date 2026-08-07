# Helper module for membership rake tasks and MembershipCleanup.
module MembershipTaskHelpers
  def self.find_matching_plan(plans, amount)
    return nil if amount.blank? || amount <= 0

    exact_match = plans.find { |p| p.cost == amount }
    return exact_match if exact_match

    tolerance = 0.50
    close_match = plans.find { |p| (p.cost - amount).abs <= tolerance }
    return close_match if close_match

    nil
  end

  def self.cutoff_for_plan(plan)
    return 1.month.ago unless plan

    case plan.billing_frequency
    when 'yearly'
      1.year.ago
    when 'one-time'
      100.years.ago
    else
      1.month.ago
    end
  end

  def self.billing_period_description(plan)
    return '1 month (default)' unless plan

    case plan.billing_frequency
    when 'monthly' then '1 month'
    when 'yearly' then '1 year'
    when 'one-time' then 'never (one-time)'
    else '1 month (default)'
    end
  end
end
