# frozen_string_literal: true

module MembershipApplications
  # Finds staff to notify about applications needing attention: whoever holds
  # applications.review through a role. Deliberately excludes the is_admin bypass, since being
  # an administrator says nothing about whether reviewing applications is your job.
  class DirectorRecipients
    PRIVILEGE = 'applications.review'

    def self.find_each(&)
      new.find_each(&)
    end

    def find_each
      User.with_privilege(PRIVILEGE).find_each do |staff|
        next if staff.email.to_s.strip.blank?

        yield staff
      end
    end
  end
end
