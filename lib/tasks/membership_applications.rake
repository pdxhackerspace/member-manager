# frozen_string_literal: true

namespace :membership_applications do
  desc 'Link membership applications to users when emails match (primary or extra_emails), case-insensitive'
  task link_by_email: :environment do
    linked = 0
    skipped = 0

    MembershipApplication.where(user_id: nil).find_each do |app|
      email = app.email.to_s.strip.downcase
      if email.blank?
        skipped += 1
        next
      end

      user = User.where('LOWER(TRIM(email)) = ?', email).first
      user ||= User.where(
        'EXISTS (SELECT 1 FROM unnest(extra_emails) AS e WHERE LOWER(TRIM(e)) = ?)',
        email
      ).first

      if user
        app.update!(user: user)
        linked += 1
        puts "Linked application #{app.id} (#{app.email}) → user #{user.id} (#{user.display_name})"
      else
        skipped += 1
      end
    end

    puts "Done. Linked #{linked} application(s); #{skipped} skipped (no match or blank email)."
  end

  desc 'Run AI feedback (Application Status Ollama profile) for submitted applications that have not been processed yet'
  task process_ai_feedback: :environment do
    scope = MembershipApplication.ai_feedback_unprocessed.order(:id)
    total = scope.count
    puts "Processing #{total} application(s) with missing AI feedback…"

    ok = 0
    skipped = 0
    failed = 0

    scope.find_each do |app|
      result = MembershipApplications::ProcessAiFeedback.call(application: app)
      if result.success?
        ok += 1
        puts "  [#{app.id}] #{app.email}: #{result.message}"
      elsif result.skipped?
        skipped += 1
        puts "  [#{app.id}] #{app.email}: skipped — #{result.message}"
      else
        failed += 1
        puts "  [#{app.id}] #{app.email}: failed — #{result.message}"
      end
    end

    puts "Done. Success: #{ok}, skipped: #{skipped}, failed: #{failed}."
  end

  desc 'Associate sent acceptance/rejection emails with finalized applications missing outcome links (preview)'
  task backfill_outcome_emails_preview: :environment do
    run_backfill_outcome_emails(dry_run: true)
  end

  desc 'Associate sent acceptance/rejection emails with finalized applications missing outcome links'
  task backfill_outcome_emails: :environment do
    run_backfill_outcome_emails(dry_run: false)
  end

  def run_backfill_outcome_emails(dry_run:)
    prefix = dry_run ? '[DRY RUN] ' : ''
    puts "#{prefix}Backfilling outcome email links for finalized membership applications…"
    puts

    result = MembershipApplications::BackfillOutcomeEmails.call(dry_run: dry_run)

    puts
    puts 'Summary:'
    puts "  Linked via queued mail: #{result.linked_queued_mail}"
    puts "  Linked via mail log snapshot: #{result.linked_snapshot}"
    puts "  Unmatched: #{result.unmatched}"
  end
end
