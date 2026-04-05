# frozen_string_literal: true

# Public multi-step application flow (email verification required).
module MembershipApplicationWizard
  extend ActiveSupport::Concern

  include Actions
  include Helpers
  include Verification

  included do
    before_action :require_verified_email!, only: %i[start save_page page submit_application]
    before_action :load_pages, only: %i[start page]
  end
end
