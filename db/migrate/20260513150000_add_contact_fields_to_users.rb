class AddContactFieldsToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :mailing_address, :text
    add_column :users, :phone_number, :string

    backfill_contact_fields_from_linked_applications
  end

  def down
    remove_column :users, :phone_number
    remove_column :users, :mailing_address
  end

  private

  def backfill_contact_fields_from_linked_applications
    execute <<~SQL.squish
      WITH linked_contact_answers AS (
        SELECT DISTINCT ON (membership_applications.user_id, application_form_questions.label)
          membership_applications.user_id,
          application_form_questions.label,
          NULLIF(BTRIM(application_answers.value), '') AS value
        FROM membership_applications
        INNER JOIN application_answers
          ON application_answers.membership_application_id = membership_applications.id
        INNER JOIN application_form_questions
          ON application_form_questions.id = application_answers.application_form_question_id
        WHERE membership_applications.user_id IS NOT NULL
          AND application_form_questions.label IN ('Mailing Address', 'Phone number')
          AND NULLIF(BTRIM(application_answers.value), '') IS NOT NULL
        ORDER BY
          membership_applications.user_id,
          application_form_questions.label,
          COALESCE(membership_applications.reviewed_at,
                   membership_applications.submitted_at,
                   membership_applications.created_at) DESC,
          membership_applications.id DESC
      ),
      pivoted_contact_answers AS (
        SELECT
          user_id,
          MAX(value) FILTER (WHERE label = 'Mailing Address') AS mailing_address,
          MAX(value) FILTER (WHERE label = 'Phone number') AS phone_number
        FROM linked_contact_answers
        GROUP BY user_id
      )
      UPDATE users
      SET
        mailing_address = COALESCE(NULLIF(BTRIM(users.mailing_address), ''), pivoted_contact_answers.mailing_address),
        phone_number = COALESCE(NULLIF(BTRIM(users.phone_number), ''), pivoted_contact_answers.phone_number)
      FROM pivoted_contact_answers
      WHERE users.id = pivoted_contact_answers.user_id
        AND (
          (NULLIF(BTRIM(users.mailing_address), '') IS NULL AND pivoted_contact_answers.mailing_address IS NOT NULL)
          OR
          (NULLIF(BTRIM(users.phone_number), '') IS NULL AND pivoted_contact_answers.phone_number IS NOT NULL)
        )
    SQL
  end
end
