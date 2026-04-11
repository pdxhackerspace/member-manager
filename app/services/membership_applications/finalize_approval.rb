# frozen_string_literal: true

module MembershipApplications
  # When an Executive Director approves an application: ensure a +User+ exists (create or link),
  # mark the application approved, journal the event, and queue +application_approved+ mail.
  class FinalizeApproval
    Result = Struct.new(:status, :queued_mail, :user, :message, keyword_init: true) do
      def success?
        status == :success
      end

      def failure?
        status == :failure
      end
    end

    CONTACT_LABELS_FOR_NOTES = [
      'Mailing Address',
      'Phone number',
      'Member Email',
      'Member Phone'
    ].freeze

    def self.call(application:, admin:, notes: nil)
      new(application: application, admin: admin, notes: notes).call
    end

    def initialize(application:, admin:, notes: nil)
      @application = application
      @admin = admin
      @notes = notes
    end

    def call
      if @application.email.to_s.strip.blank?
        return Result.new(status: :failure, queued_mail: nil, user: nil,
                          message: 'Application has no email address.')
      end
      if @application.draft?
        return Result.new(status: :failure, queued_mail: nil, user: nil,
                          message: 'Draft applications cannot be approved.')
      end
      if @application.approved? || @application.rejected?
        return Result.new(status: :failure, queued_mail: nil, user: nil,
                          message: 'This application has already been finalized.')
      end

      user = nil
      queued_mail = nil

      MembershipApplication.transaction do
        @application.lock!

        if @application.approved? || @application.rejected?
          return Result.new(status: :failure, queued_mail: nil, user: nil,
                            message: 'This application has already been finalized.')
        end

        user = resolve_recipient_user!
        @application.update!(
          status: 'approved',
          reviewed_by: @admin,
          reviewed_at: Time.current,
          admin_notes: @notes,
          user_id: user.id
        )
        Journal.record_application_event!(
          application: @application,
          action: 'application_approved',
          actor: @admin
        )
        queued_mail = QueuedMail.enqueue(
          :application_approved,
          user,
          reason: 'Application approved',
          to: user.email
        )
      end

      Result.new(status: :success, queued_mail: queued_mail, user: user, message: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(status: :failure, queued_mail: nil, user: nil,
                 message: e.record.errors.full_messages.to_sentence)
    rescue StandardError => e
      Rails.logger.error("[FinalizeApproval] #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
      Result.new(status: :failure, queued_mail: nil, user: nil, message: e.message)
    end

    private

    def resolve_recipient_user!
      if @application.user.present?
        return merge_application_into_user!(@application.user)
      end

      email = @application.email.to_s.strip.downcase

      existing = User.where('LOWER(TRIM(email)) = ?', email).first
      existing ||= User.where(
        'EXISTS (SELECT 1 FROM unnest(extra_emails) AS e WHERE LOWER(TRIM(e)) = ?)',
        email
      ).first

      return merge_application_into_user!(existing) if existing

      User.create!(new_user_attributes(email))
    end

    def new_user_attributes(email)
      attrs = {
        email: email,
        full_name: derived_full_name,
        membership_status: 'applicant',
        active: false,
        service_account: false
      }
      pn = answer_for_label('Pronouns')
      attrs[:pronouns] = pn if pn.present?
      notes = contact_notes_section
      attrs[:notes] = notes if notes.present?
      attrs.compact
    end

    def merge_application_into_user!(user)
      attrs = {}
      name = derived_full_name
      attrs[:full_name] = name if user.full_name.blank? && name.present?
      pn = answer_for_label('Pronouns')
      attrs[:pronouns] = pn if user.pronouns.blank? && pn.present?
      extra_notes = contact_notes_section
      if extra_notes.present?
        attrs[:notes] = [user.notes, "From membership application:\n#{extra_notes}"].compact.join("\n\n").strip
      end
      user.update!(attrs) if attrs.any?
      user.reload
    end

    def derived_full_name
      name = @application.applicant_display_name
      return name if name.present? && name != '—'

      local = @application.email.to_s.split('@', 2).first.to_s
      return nil if local.blank?

      local.tr('_', ' ').titleize
    end

    def answer_for_label(label)
      q = ApplicationFormQuestion.find_by(label: label)
      return nil unless q

      @application.application_answers.find_by(application_form_question: q)&.value&.strip.presence
    end

    def contact_notes_section
      lines = CONTACT_LABELS_FOR_NOTES.filter_map do |label|
        val = answer_for_label(label)
        next if val.blank?

        "#{label}: #{val}"
      end
      lines.join("\n").presence
    end
  end
end
