require 'test_helper'
require Rails.root.join('db/migrate/20260513150000_add_contact_fields_to_users')

class AddContactFieldsToUsersTest < ActiveSupport::TestCase
  test 'backfills blank user contact fields from the newest linked application' do
    user = users(:member_with_local_account)
    user.update!(mailing_address: nil, phone_number: nil)

    old_app = linked_application_for(user, email: 'old-contact-backfill@example.com', submitted_at: 2.days.ago)
    old_app.application_answers.create!(application_form_question: mailing_address_question, value: 'Old Address')
    old_app.application_answers.create!(application_form_question: phone_number_question, value: '555-000-0000')

    new_app = linked_application_for(user, email: 'new-contact-backfill@example.com', submitted_at: 1.day.ago)
    new_app.application_answers.create!(application_form_question: mailing_address_question, value: 'New Address')
    new_app.application_answers.create!(application_form_question: phone_number_question, value: '555-111-2222')

    AddContactFieldsToUsers.new.send(:backfill_contact_fields_from_linked_applications)

    user.reload
    assert_equal 'New Address', user.mailing_address
    assert_equal '555-111-2222', user.phone_number
  end

  test 'backfill does not replace existing user contact fields' do
    user = users(:one)
    user.update!(mailing_address: 'Existing Address', phone_number: '555-999-9999')

    app = linked_application_for(user, email: 'preserve-contact-backfill@example.com', submitted_at: 1.day.ago)
    app.application_answers.create!(application_form_question: mailing_address_question, value: 'Application Address')
    app.application_answers.create!(application_form_question: phone_number_question, value: '555-333-4444')

    AddContactFieldsToUsers.new.send(:backfill_contact_fields_from_linked_applications)

    user.reload
    assert_equal 'Existing Address', user.mailing_address
    assert_equal '555-999-9999', user.phone_number
  end

  private

  def linked_application_for(user, email:, submitted_at:)
    MembershipApplication.create!(
      email: email,
      user: user,
      status: 'approved',
      submitted_at: submitted_at,
      reviewed_at: submitted_at
    )
  end

  def contact_page
    @contact_page ||= ApplicationFormPage.create!(title: 'Migration Contact', position: 22_000)
  end

  def mailing_address_question
    @mailing_address_question ||= contact_page.questions.create!(
      label: 'Mailing Address',
      field_type: 'text',
      required: false,
      position: 1
    )
  end

  def phone_number_question
    @phone_number_question ||= contact_page.questions.create!(
      label: 'Phone number',
      field_type: 'text',
      required: false,
      position: 2
    )
  end
end
